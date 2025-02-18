#include <iostream>
#include <string>
#include <fstream>
#include <sstream>
#include <map>
#include <clang-c/Index.h>

#define CLANG_ARGS "-std=c++14", "-D__SYNTHESIS__=1"


typedef std::map<unsigned int, std::string> func_linenum_table_t;

enum ERROR_STATUS{
    SUCCESS = 0,
    ERROR_CLANG = -1,
    ERROR_FILE = -2
};

CXChildVisitResult Visitor(CXCursor cursor, CXCursor parent, CXClientData clientData) {
    func_linenum_table_t* functionDeclarations =
        static_cast<func_linenum_table_t*>(clientData);

    // Process only function declarations for this example
    if (clang_getCursorKind(cursor) == CXCursor_FunctionDecl) {
        // Get the function name
        CXString functionName = clang_getCursorSpelling(cursor);
        std::string functionName_cstr = clang_getCString(functionName);
        clang_disposeString(functionName);

        CXSourceLocation location = clang_getCursorLocation(cursor);
        CXFile file;
        unsigned int line, column, offset;
        clang_getSpellingLocation(location, &file, &line, &column, &offset);
        
        CXString fileName = clang_getFileName(file);
        std::string fileName_cstr = clang_getCString(fileName);
        clang_disposeString(fileName);
        /*
        std::cout << "Function: " << functionName_cstr         \
                  << " File: " << fileName_cstr   \
                  << " Line: " << line << std::endl;
        */
        
        unsigned int match_hls_pattern = 0;
        if (functionName_cstr.find("_hls") != std::string::npos) {
            ++match_hls_pattern;
        }
        if (fileName_cstr.find(".c") != std::string::npos) {
            ++match_hls_pattern;
        }
        
        // Insert the function declaration into the unordered_map
        if (match_hls_pattern == 2) {
            functionDeclarations->insert({line, functionName_cstr});
        }
    }

    return CXChildVisit_Recurse;
}

bool ExtractFunc(const char *filename, func_linenum_table_t *functionDeclarations){
    const char* args[] = {CLANG_ARGS};  // additional compiler arguments if needed
    CXIndex index = clang_createIndex(0, 0);

    CXTranslationUnit translationUnit = clang_parseTranslationUnit(
        index, filename, args, sizeof(args) / sizeof(args[0]), nullptr, 0,
        CXTranslationUnit_None);

    if (translationUnit == nullptr) {
        std::cerr << "Failed to parse translation unit." << std::endl;
        return false;
    }
    
    CXCursor cursor = clang_getTranslationUnitCursor(translationUnit);

    clang_visitChildren(
        cursor,
        Visitor,
        functionDeclarations);

    clang_disposeTranslationUnit(translationUnit);
    clang_disposeIndex(index);
    return true;
}


std::string addModifiedToFile(const std::string& filePath) {
    // Find the last occurrence of '/' or '\' to separate the directory path and the file name
    size_t lastPathSeparatorPos = filePath.find_last_of("/\\");
    if (lastPathSeparatorPos == std::string::npos) {
        lastPathSeparatorPos = 0; // If no separator is found, assume the whole string is the file name
    } else {
        lastPathSeparatorPos += 1; // Include the separator in the file name
    }

    // Find the position of the file extension separator ('.') starting from the last path separator
    size_t extensionSeparatorPos = filePath.find('.', lastPathSeparatorPos);

    // Extract the directory path, file name, and file extension
    std::string directoryPath = filePath.substr(0, lastPathSeparatorPos);
    std::string fileName = filePath.substr(lastPathSeparatorPos, extensionSeparatorPos - lastPathSeparatorPos);
    std::string fileExtension = filePath.substr(extensionSeparatorPos);

    // Append "_modified" to the file name
    std::string modifiedFileName = fileName + "_modified";

    // Construct the modified file path by combining the directory path, modified file name, and file extension
    std::string modifiedFilePath = directoryPath + modifiedFileName + fileExtension;

    return modifiedFilePath;
}

bool replaceLineContent(const std::string& filepath, const func_linenum_table_t& func_linenum_table) {
    std::ifstream inputFile(filepath);
    
    std::string out_filepath = addModifiedToFile(filepath);
    
    std::cout << "Generate " << out_filepath << std::endl;
    
    std::ofstream outputFile(out_filepath);
    
    if (!inputFile) {
        std::cerr << "Failed to open input file: " << filepath<< std::endl;
        return false;
    }
    
    if (!outputFile) {
        std::cerr << "Failed to create output file: " << out_filepath << std::endl;
        return false;
    }
    
    std::string line;
    unsigned int currentLineNumber = 1;
    unsigned int replaceLineNumber = 0;
    int findidx;
    bool add_hls_capture_c = true;

    while (std::getline(inputFile, line)) {
        if (currentLineNumber == 1){
            findidx = line.find("hls_config.h");
            if (findidx == std::string::npos){
                outputFile << "#include \"hls_config.h\"" << std::endl;
                std::cout << "Add #include \"hls_capture.h\"" << std::endl;
            }
        } else {
            findidx = line.find("hls_capture.cpp");
            if (findidx != std::string::npos){
                add_hls_capture_c = false;
            }
        }
        
        auto it = func_linenum_table.find(currentLineNumber);
        if (it != func_linenum_table.end()) {
            const std::string &funcName = it->second;

            std::string impl_funcName = "IMPL(";
            impl_funcName += funcName;
            impl_funcName += ")";
        
            findidx = line.find(impl_funcName);
            if (findidx != std::string::npos){
                // found IMPL(funcName), skip replace
            } else {
                findidx = line.find(funcName);
                if (findidx != std::string::npos){

                    line.replace(findidx, funcName.length(), impl_funcName);
                    ++replaceLineNumber;
                }
            }
        }
        outputFile << line << std::endl;
        currentLineNumber++;
    }
    
    if(add_hls_capture_c) {
        outputFile << "#if CAPTURE_COSIM\n    #include \"hls_capture.cpp\"\n#endif" << std::endl;
        std::cout << "Add #include \"hls_capture.cpp\"" << std::endl;
    }
    
    std::cout << "Total replaced line number: " << replaceLineNumber << std::endl;
    
    inputFile.close();
    outputFile.close();

    return true;
}

int main(int argc, const char *argv[]) {
    if (argc != 2) {
        std::cout << "Usage: Add IMPL() macro for each HLS functions (The function name ends with _hls)" << std::endl;
        std::cout << argv[0] << " [hls_file_path]" << std::endl;
        return SUCCESS;
    }

    const char* filename = argv[1];
    func_linenum_table_t functionDeclarations;

    if (!ExtractFunc(filename, &functionDeclarations)){
        return ERROR_CLANG;
    }

    // Print the function declarations stored in the unordered_map
    for (const auto& entry : functionDeclarations) {
        std::cout << "Line " << entry.first << ": " << entry.second << std::endl;
    }
    
    std::cout << "Total function number: " << functionDeclarations.size() << std::endl;
    
    if (!replaceLineContent(filename, functionDeclarations)){
        return ERROR_FILE;
    }

    return SUCCESS;
}