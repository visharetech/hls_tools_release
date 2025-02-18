#define _CRT_SECURE_NO_WARNINGS
#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <cinttypes>
#include <cstring>
#include <queue>
#include <unordered_map>
#include <vector>
#include <string>
#include <sstream>
#include <type_traits>
#include <iostream>
#include <algorithm>
#include <memory>
#include "tgcommon.h"
#include "xmem.h"

typedef uint8_t datatype_t;

//#define DEBUG   1

#ifndef ARRAY_SIZE
#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof((arr)[0]))
#endif

#define QUOTE(...) #__VA_ARGS__

typedef struct {
    unsigned int var_id;
    bool is_after_capture;
    unsigned int buf_idx;
    unsigned int buf_size;
    unsigned int count_id;
} capture_marker_t;

typedef struct signal_info{
    uint32_t width;
    datatype_t datatype;
    std::vector<uint8_t> content;

    signal_info(){
        width = 0;
        datatype = UNKNWON_TYPE;
    }

    void clear_data() {
        content.clear();
    }
}signal_info_t;


class Ctgload{
public:
    Ctgload(){
        fi = NULL;
    }

    ~Ctgload(){
        if(fi != NULL){
            fclose(fi);
        }
    }

    bool open(const char *filepath)
    {
        bool rc = true;

        const char *search_path[] = {"",
                                    "../../../",
                                    "../../../capture_data/"
        };

        uint32_t signum = 0;
        std::string signame;
        signal_info_t sig_info;

        bool file_exist = false;
        std::string exist_filepath;
        for (unsigned int i=0; i<ARRAY_SIZE(search_path); i++){
            exist_filepath.assign(search_path[i]);
            exist_filepath.append(filepath);
            if (access(exist_filepath.c_str(), F_OK) == 0) {
                //std::cout << exist_filepath << " exists.\n";
                file_exist = true;
                break;
            }
        }

        if (!file_exist) {
            std::cout << filepath << " does not exist in dedicated directories .\n";
            rc = false;
            goto EXIT;
        }

        fi = fopen(exist_filepath.c_str(), "rb");
        if (fi == NULL){
            std::cout << filepath << " could not be opened.\n";
            rc = false;
            goto EXIT;
        }

        char file_signature[4];
        if (fread(file_signature, 1, sizeof(file_signature), fi) != sizeof(file_signature)) {
            fclose(fi);
            rc = false;
            goto EXIT;
        }

        if (memcmp(file_signature, "TB01", 4) != 0) {
            std::cout << "Invalid file signature\n";
            fclose(fi);
            rc = false;
            goto EXIT;
        }


        if (fread(&signum, 1, sizeof(signum), fi) != sizeof(signum)) {
            fclose(fi);
            rc = false;
            goto EXIT;
        }

        for (int i = 0; i < signum; i++) {
            uint32_t signame_len;
            if (fread(&signame_len, 1, sizeof(signame_len), fi) != sizeof(signame_len)) {
                signum = 0;
                rc = false;
                goto EXIT;
            }

            if (signame_len > 256) {
                printf("signame_len exceed 256\n");
                signum = 0;
                rc = false;
                goto EXIT;
            }
            char tmp_signame[256];
            if (fread(tmp_signame, 1, signame_len, fi) != signame_len) {
                signum = 0;
                rc = false;
                goto EXIT;
            }
            tmp_signame[signame_len] = '\0';

            signame = trim_string(tmp_signame);

            if (fread(&sig_info.width, sizeof(sig_info.width), 1, fi) != 1) {
                signum = 0;
                rc = false;
                goto EXIT;
            }

            load_order.push_back(signame);
            sinfo[signame] = sig_info;
            std::cout << "tgload:" << signame << ",width:" << sig_info.width << '\n';
        }
        
    EXIT:
        if (!rc) {
            //exit immediately with error code
            exit(-1);
        }
        return rc;
    }

    int read_data(bool after_capture){
        while(1) {
            uint32_t var_id;
            uint32_t buf_size;

            if (fread(&var_id, sizeof(var_id), 1, fi) != 1) {
                return (feof(fi) != 0) ? EOF : 0;
            }

            if (!after_capture && var_id == TESTDATA_CAPTURE_BEFORE_END){
#if DEBUG
                printf("before capture tag found\n");
#endif
                return (feof(fi) != 0) ? EOF : 0;
            } else if (after_capture && var_id == TESTDATA_CAPTURE_AFTER_END){
#if DEBUG
                printf("after capture tag found\n");
#endif
                return (feof(fi) != 0) ? EOF : 0;
            }

            if (fread(&buf_size, sizeof(buf_size), 1, fi) != 1) {
                return ferror(fi);
            }

#if DEBUG
            printf("var_id: %d bufsize:%d\n", var_id, buf_size);
#endif

            if (var_id > load_order.size()-1){
                printf("var_id out of range");
                exit(-1);
            }

            const std::string& signame = load_order[var_id];

            auto it = sinfo.find(signame);
            if (it == sinfo.end()) {
                printf("Cannot find the signame\n");
                exit(-1);
            }

            auto & test_content = it->second.content;

            if (buf_size > test_content.size()) {
                //resize the vector only if the size is smaller than read buf_size
                test_content.reserve(buf_size);
                test_content.resize(buf_size);
            }
            if (fread(test_content.data(), 1, buf_size, fi) != buf_size) {
                return ferror(fi);
            }
        }
        return 0;
    }

    void pop(std::istringstream &paralist_str) {
    }

    // Variadic template function to handle multiple variables
    template <typename T, typename... Args>
    typename std::enable_if<!std::is_class<T>::value, void>::type
    pop(std::istringstream &paralist_str, T &data, Args&&... args){
        std::string varname;
        std::getline (paralist_str, varname, ',');
        varname = trim_string(varname);
#if DEBUG
        std::cout << "pop:T:" << (int)get_datatype(data) << ' ' << varname << ' ' << sinfo[varname].width << '\n';
#endif
        pop_data(varname, (uint8_t*)&data, sizeof(T));

        pop(paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
    }

    template <typename T, size_t N, typename... Args>
    typename std::enable_if<!std::is_class<T>::value, void>::type
    pop(std::istringstream &paralist_str, T(&data)[N], Args&&... args){
        std::string varname;
        std::getline (paralist_str, varname, ',');
        varname = trim_string(varname);
#if DEBUG
        std::cout << "pop:array:" << (int)get_datatype(data) << ' ' << varname << ' ' << sinfo[varname].width << '\n';
#endif
        pop_data(varname, (uint8_t*)&data[0], sizeof(T)*N);
        pop(paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
    }

    template <typename T, typename... Args>
    typename std::enable_if<std::is_class<T>::value, void>::type
    pop(std::istringstream &paralist_str, T &data, Args&&... args){
        std::string varname;
        std::getline (paralist_str, varname, ',');
        varname = trim_string(varname);
#if DEBUG
        std::cout << "pop:struct:" << (int)get_datatype(data) << ' ' << varname << ' ' << sinfo[varname].width << '\n';
#endif
        override_pop(*this, varname, data);

        pop(paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
    }

    //====================================================


    void check(std::istringstream &paralist_str) {
    }

    // Variadic template function to handle multiple variables
    template <typename T, typename... Args>
    typename std::enable_if<!std::is_class<T>::value, void>::type
    check(std::istringstream &paralist_str, T &data, Args&&... args){
        std::string varname;
        std::getline (paralist_str, varname, ',');
        varname = trim_string(varname);
#if DEBUG
        std::cout << "chk:T:" << (int)get_datatype(data) << ' ' << varname << ' ' << sinfo[varname].width << '\n';
#endif
        check_data(varname, data);

        check(paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
    }

    template <typename T, size_t N, typename... Args>
    typename std::enable_if<!std::is_class<T>::value, void>::type
    check(std::istringstream &paralist_str, T(&data)[N], Args&&... args){
        std::string varname;
        std::getline (paralist_str, varname, ',');
        varname = trim_string(varname);
#if DEBUG
        std::cout << "chk:array:" << (int)get_datatype(data) << ' ' << varname << ' ' << N << ' ' << sinfo[varname].width << '\n';
#endif
        //for(size_t i=0; i<N; i++){
        //    printf("N:%d %d\n", i, data[i]);
            check_data(varname, data);
        //}

        check(paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
    }


    template <typename T, typename... Args>
    typename std::enable_if<std::is_class<T>::value, void>::type
    check(std::istringstream &paralist_str, T &data, Args&&... args){
        std::string varname;
        std::getline (paralist_str, varname, ',');
        varname = trim_string(varname);
#if DEBUG
        std::cout << "chk:struct:" << (int)get_datatype(data) << ' ' << varname << ' ' << sizeof(data)<< '\n';
#endif
        override_pop(*this, varname, data);

        check(paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
    }



private:

    std::string trim_string(const std::string& str){
        auto start = str.find_first_not_of(" \t\n\r");
        auto end = str.find_last_not_of(" \t\n\r");
        if (start == std::string::npos || end == std::string::npos) {
            return "";
        }
        return str.substr(start, end - start + 1);
    }

    void pop_data(const std::string &signame, uint8_t *ptr, size_t data_size)
    {
        auto &siginfo = sinfo.at(signame);
        //uint32_t width = siginfo.content.size();
        memcpy(ptr, siginfo.content.data(), data_size);
    }


    template<typename T>
    void check_data(const std::string& signame, const T& var) {
        T var2;
        pop_data(signame, (uint8_t*)&var2, sizeof(T));
        if (std::memcmp(&var, &var2, sizeof(T)) != 0) {
            std::cout << "tgCheckError: " << signame << " ,sizeOf: " << sizeof(T) << std::endl;

            dump_content("actual_result", &var, sizeof(T));
            dump_content("expect_result", &var2, sizeof(T));
            
            exit(-1);
        }
    }

    FILE* fi;
    std::vector<std::string> load_order;
    std::unordered_map<std::string, signal_info_t> sinfo;

    void dump_content(const char *s, const void* buf, size_t size){
        printf("%s\n", s);

        const uint8_t *pbuf8 = (const uint8_t *) buf;

        for (size_t i=0; i<size; i++){
            printf("%02x ", pbuf8[i]);

            if (((i+1)%16) == 0) {
                printf("\n");
            } 
        }
        printf("\n");
    }
};

#define tgLoad(filepath)    Ctgload tgload;                                 \
                            if (!tgload.open(filepath)) {                   \
                                printf("Open file %s failed\n", filepath);  \
                                exit(-1);                                   \
                            }

#define tgPop(...) do {\
    std::string argvstr = QUOTE(__VA_ARGS__);   \
    std::istringstream sn(argvstr);             \
    int status = tgload.read_data(false);       \
    if (status == EOF) {                        \
        finish = true;                          \
    } else if (status != 0) {                   \
        printf("load test data error\n");       \
        exit(-1);                               \
    }                                           \
    tgload.pop(sn, __VA_ARGS__);                \
} while (0)

#define tgCheck(...) do {\
    std::string argvstr = QUOTE(__VA_ARGS__);   \
    std::istringstream sn(argvstr);             \
    int status = tgload.read_data(true);        \
    if (status == EOF) {                        \
        finish = true;                          \
    } else if (status != 0) {                   \
        printf("load test data error\n");       \
        exit(-1);                               \
    }                                           \
    tgload.check(sn, __VA_ARGS__);              \
} while (0)


//specialized for struct type
template<typename T>
void override_pop(Ctgload &tgload, const std::string& var_name, T &mv){
    std::cout << "pop func should specialized " << var_name << ',' << sizeof(T) <<'\n';
    exit(-1);
}

#if 1

//specialized for tutorial example vector_2d
template<> void override_pop<vector_2d>(Ctgload &tgload, const std::string& var_name, vector_2d &vec)
{
    std::stringstream inner_ss;
    inner_ss << var_name << "_x,";
    inner_ss << var_name << "_y,";

    std::istringstream inner_iss(inner_ss.str());

    tgload.pop(inner_iss, vec.x, vec.y);
}

#endif

template<> void override_pop<xmem_t>(Ctgload &tgload, const std::string& var_name, xmem_t &xmem)
{

}

template<> void override_pop<child_cmd_t>(Ctgload &tgload, const std::string& var_name, child_cmd_t &cmd)
{
    std::stringstream inner_ss;
    inner_ss << var_name << "_id,";
    inner_ss << var_name << "_param,";

    std::istringstream inner_iss(inner_ss.str());

    tgload.pop(inner_iss, cmd.id, cmd.param);
}