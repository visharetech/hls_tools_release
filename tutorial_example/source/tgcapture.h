#ifndef _TGCAPTURE_H_
#define _TGCAPTURE_H_

#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <type_traits>
#include <unordered_map>
#include <vector>
#include <list>
#include <algorithm>
#include <type_traits>
#include <string.h>
#include <unordered_set>
#include <limits.h>
#include <queue>
#include <atomic>
#include <pthread.h>
#include "tgcommon.h"

#include "common_with_hls.h"
#include "xmem.h"

//#define DEBUG 1
//#define SHOW_CAPTURE_DATA         1
#define CAPTURE_SHORT_SIGNAME     1

typedef struct {
	bool is_after_capture;
    unsigned int buf_idx;
    unsigned int buf_size;
    unsigned int count_id;
} capture_marker_t;

typedef struct signal_info{
    unsigned int width;
    datatype_t datatype;
    std::vector<uint8_t> capture_data;          //Save the actual data byte
    std::vector<capture_marker_t> capture_marker;
    uint32_t write_file_complete_idx;

    signal_info(){
        width = 0;
        datatype = UNKNWON_TYPE;
        write_file_complete_idx = 0;
    }

    void clear_data() {
        capture_data.clear();
        capture_marker.clear();
    }
}signal_info_t;

enum PARENT_FUNCTION_STATUS{
    PARENT_FUNC_NONE,
    PARENT_FUNC_MATCHED,
    PARENT_FUNC_NOT_MATCHED
};

class CCapture;

//------------------------------------------------------------------------------------

class CCaptureGroup{
    public:
        std::unordered_map<pthread_t, CCapture*> items;
        ~CCaptureGroup();
};    


extern CCaptureGroup capture_group;



class CCapture {
public:
    enum CAPTURE_STATUS{
        ON_OPEN,
        ON_CAPTURE
    };

public:
    CCapture(){
        var_idx_cnt = 0;
        capture_count = 0;
        capture_after_flag = false;
        inside_parent_func = false;
        before_capture_order_idx = -1;
        after_capture_order_idx = -1;
        parent_func_flag = false;
    }

    CCapture(const char *func_name, bool parent_flag){
        var_idx_cnt = 0;
        capture_count = 0;
        capture_after_flag = false;
        inside_parent_func = false;

        before_capture_order_idx = -1;
        after_capture_order_idx = -1;

        parent_func_flag = parent_flag;
        if (parent_flag) {      
            set_parent_func(func_name);
        }
    }

    ~CCapture(){
        close();
    }

    static bool is_inside_parent_func(){
        pthread_t self_tid = pthread_self();
        auto iter = capture_group.items.find(self_tid);
        if (iter == capture_group.items.end()){
            return false;
        }
        if (iter->second == nullptr){
            return false;
        }
        return iter->second->inside_parent_func;
    }

    inline void set_inside_parent_func(bool flag){
        inside_parent_func = flag;
    }

    inline unsigned int get_capture_count(){
        if (!parent_func.empty()) {
            return parent_capture_count;
        }
        return capture_count;
    }

    void set_logfile(const char *path){
        filepath = path;
    }

    void set_logfile(const std::string &path){
        filepath = path;
    }

    bool is_inited(const std::string &func_name) {
        return func_grp.find(func_name) != func_grp.end();
    }

    void init_var(const std::string &func_name, std::istringstream &paralist_str) {
        func_grp.insert(func_name);
    }

    static enum PARENT_FUNCTION_STATUS is_parent_func(const char *func_name) {
        if (parent_func.empty()){
            return PARENT_FUNC_NONE;
        }
        std::string str_func_name(func_name);
        return (str_func_name == parent_func) ? PARENT_FUNC_MATCHED : PARENT_FUNC_NOT_MATCHED;
    }

    // Variadic template function to handle multiple variables
    template <typename T, typename... Args>
    typename std::enable_if<!std::is_class<T>::value, void>::type
    init_var(const std::string &func_name, std::istringstream &paralist_str, const T &data, Args&&... args){
        std::string varname;
        std::getline (paralist_str, varname, ',');

#if CAPTURE_SHORT_SIGNAME
        varname = trim_string(varname);
#else
        varname = func_name + "." + trim_string(varname);
#endif
        
#if DEBUG || SHOW_CAPTURE_DATA
        std::cout << "init_var:T:" << (int)get_datatype(data) << ' ' << varname << ' ' << sizeof(data)<< '\n';
#endif

        auto it = sinfo.find(varname);
        if (it == sinfo.end()) {
            signal_info_t info;
            info.width = sizeof(data);
            info.datatype = get_datatype(data);
            sinfo[varname] = info;
            var_id_table[varname] = var_idx_cnt;
            var_id_resv_table[var_idx_cnt] = varname;
            var_idx_cnt++;
        }

        init_var(func_name, paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
    }


    template <typename T, typename... Args>
    typename std::enable_if<std::is_class<T>::value, void>::type
    init_var(const std::string &func_name, std::istringstream &paralist_str, const T &data, Args&&... args){
        std::string varname;
        std::getline (paralist_str, varname, ',');

#if CAPTURE_SHORT_SIGNAME
        varname = trim_string(varname);
#else
        varname = func_name + "." + trim_string(varname);
#endif

#if DEBUG || SHOW_CAPTURE_DATA
        std::cout << "init_var:struct:" << (int)get_datatype(data) << ' ' << varname << ' ' << sizeof(data)<< '\n';
#endif
        override_capture(*this, ON_OPEN, func_name, varname, data);

        init_var(func_name, paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
    }

    void mark_capture_before(){
        capture_after_flag = false;
    }

    void mark_capture_after(){
        capture_after_flag = true;
    }

    void inc_capture_count(const char *func_name){
        ++capture_count;
        if (func_name == parent_func){
            ++parent_capture_count;
        }
#if DEBUG || SHOW_CAPTURE_DATA
        printf("============ capture_count: %s %d %d ============\n", func_name, parent_capture_count.load(), capture_count);
#endif
    }


    void capture(const std::string &func_name, std::istringstream &sn){
    }

    template <typename T, std::size_t N, typename... Args>
    void capture(const std::string &func_name, std::istringstream &sn, const T(&value)[N], Args&&... args) {
        std::string varname;
        std::getline(sn, varname, ',');

#if CAPTURE_SHORT_SIGNAME
        varname = trim_string(varname);
#else
        varname = func_name + "." + trim_string(varname);
#endif

#if DEBUG || SHOW_CAPTURE_DATA
        std::cout   << "capture:array:" << (capture_after_flag ? 'e' : 's')     \
                    << "type:" << (int)get_datatype(value) << ','               \
                    << varname << ",size:" << sizeof(T)                         \
                    << ",count:" << parent_capture_count << ',' << capture_count << '\n';
#endif
        signal_info_t &siginfo = sinfo[varname];

        write_data(varname, &siginfo, &value[0], sizeof(T), N);

        capture(func_name, sn, std::forward<Args>(args)...);
    }


    template <typename T, typename... Args>
    typename std::enable_if<std::is_class<T>::value>::type
    capture(const std::string &func_name, std::istringstream &sn, const T& value, Args&&... args) {

        std::string varname;
        std::getline(sn, varname, ',');

#if CAPTURE_SHORT_SIGNAME
        varname = trim_string(varname);
#else
        varname = func_name + "." + trim_string(varname);
#endif

#if DEBUG || SHOW_CAPTURE_DATA
        std::cout   << "capture:struct:" << (capture_after_flag ? 'e' : 's')    \
                    << "type:" << (int)get_datatype(value) << ','               \
                    << varname << ",size:" << sizeof(T)                         \
                    << ",count:" << parent_capture_count << ',' << capture_count << '\n';
#endif
        override_capture(*this, ON_CAPTURE, func_name, varname, value);
        capture(func_name, sn, std::forward<Args>(args)...);
    }


    template <typename T, typename... Args>\
    typename std::enable_if<!std::is_pointer<T>::value && !std::is_array<T>::value && !std::is_class<T>::value>::type
    capture(const std::string &func_name, std::istringstream &sn, const T& value, Args&&... args) {
        std::string varname;
        std::getline(sn, varname, ',');

#if CAPTURE_SHORT_SIGNAME
        varname = trim_string(varname);
#else
        varname = func_name + "." + trim_string(varname);
#endif

#if DEBUG || SHOW_CAPTURE_DATA
        std::cout   << "capture:native:" << (capture_after_flag ? 'e' : 's')    \
                    << "type:" << (int)get_datatype(value) << ','               \
                    << varname << ",size:" << sizeof(T)                         \
                    << ",count:" << parent_capture_count << ',' << capture_count << '\n';
#endif
        signal_info_t &siginfo = sinfo[varname];

        write_data(varname, &siginfo, &value, sizeof(value), 1);

        capture(func_name, sn, std::forward<Args>(args)...);
    }

    template <typename T, typename... Args>
    typename std::enable_if<std::is_pointer<T>::value>::type
    capture(const std::string &func_name, std::istringstream &sn, const T& value, size_t num_elements, Args&&... args) {
        std::string varname;
        std::getline(sn, varname, ',');

#if CAPTURE_SHORT_SIGNAME
        varname = trim_string(varname);
#else
        varname = func_name + "." + trim_string(varname);
#endif

        std::string numElementStr;
        std::getline(sn, numElementStr, ',');
#if DEBUG || SHOW_CAPTURE_DATA
        std::cout   << "capture:pointer:" << (capture_after_flag ? 'e' : 's')           \
                    << "type:" << (int)get_datatype(value) << ','                       \
                    << varname <<  ",size:" << sizeof(*value) << ',' << num_elements    \
                    << ",count" << parent_capture_count << ',' << capture_count << '\n';
#endif

        signal_info_t &siginfo = sinfo[varname];


        if (value == NULL){
            auto iter = warn_msg.find(varname);
            if (iter == warn_msg.end()) {
                std::cout << "*** WARNING: " << varname << " is NULL during capture data ***\n";
                warn_msg.insert(varname);
            }

            uint8_t *fillzero = new uint8_t[sizeof(*value) * num_elements];
            memset(fillzero, 0, sizeof(*value) * num_elements);
            write_data(varname, &siginfo, fillzero, sizeof(*value), num_elements);
            delete [] fillzero;
        } else {
            write_data(varname, &siginfo, value, sizeof(*value), num_elements);
        }
        capture(func_name, sn, std::forward<Args>(args)...);
    }

    std::string trim_export_signame(const std::string& signame) {
        if (parent_func.empty()){
            size_t dotPosition = signame.find('.');
            if (dotPosition != std::string::npos) {
                return signame.substr(dotPosition + 1);
            }
        }

        return signame; // Return an empty string if no dot is found
    }

    void close(){
        if (sinfo.size() == 0){
            return ;
        }

        if(!parent_func.empty()){
            printf("*** Capture Parent and Child function ***\n");
        }

        std::ofstream file(filepath, std::ios::binary);
        std::cout << "write file to " << filepath << '\n';

        uint32_t num = 0;
        for (auto & s : sinfo) {
            //std::cout << "---" << s.first << '\n';
            if (s.second.capture_data.size() != 0) {
                std::cout << s.first << ',' << s.second.capture_data.size() <<'\n';
                num++;
            }
        }

        const char file_signature[] = {'T', 'B', '0', '1'};
        file.write(file_signature, sizeof(file_signature));
        file.write(reinterpret_cast<const char*>(&num), sizeof(num));

        std::cout << "capture count:" << get_capture_count() << '\n';

        printf("capture signal number: %u\n", num);

        for (int var_id = 0; var_id<var_id_resv_table.size(); var_id++) {
            const std::string &signame = var_id_resv_table[var_id];
            const signal_info_t & info = sinfo[signame];
            uint32_t signame_len = signame.length();
            file.write(reinterpret_cast<const char*>(&signame_len), sizeof(signame_len));
            file.write(reinterpret_cast<const char*>(signame.c_str()), signame.length());
            file.write(reinterpret_cast<const char*>(&info.width), sizeof(info.width));
        }
    
        unsigned int cur_count_id = 0;
        bool cur_after_flag = false;

        for (uint32_t var_id : capture_order) {
            const std::string &var_name = var_id_resv_table[var_id];
            signal_info_t & info = sinfo[var_name];

            const capture_marker_t &marker = info.capture_marker[info.write_file_complete_idx];

            bool is_after_capture = marker.is_after_capture;
            unsigned int count_id = marker.count_id;

            if (!cur_after_flag) {
                if (is_after_capture) {
                    //Add the marker to indicate the end of the capture (before) data
                    file.write(reinterpret_cast<const char*>(&TESTDATA_CAPTURE_BEFORE_END), 4);
#if DEBUG
                    printf("Write TESTDATA_CAPTURE_BEFORE_END\n");
#endif
                }
            } else {
                if(!is_after_capture) {
                    //Add the marker to indicate the end of the capture (after) data
                    file.write(reinterpret_cast<const char*>(&TESTDATA_CAPTURE_AFTER_END), 4);
#if DEBUG
                    printf("Write TESTDATA_CAPTURE_AFTER_END\n");
#endif
                }
            }

            cur_after_flag = is_after_capture;

#if DEBUG
            printf("write %s %d %d %c\n", var_name.c_str(), count_id, marker.buf_idx, marker.is_after_capture ? 'e' : 's');
#endif

            file.write(reinterpret_cast<const char*>(&var_id), 4);
            file.write(reinterpret_cast<const char*>(&marker.buf_size), 4);
            file.write(reinterpret_cast<const char*>(info.capture_data.data() + marker.buf_idx), marker.buf_size);
            info.write_file_complete_idx++;
        }

        //Add the marker to indicate the end of the capture (after) data
        file.write(reinterpret_cast<const char*>(&TESTDATA_CAPTURE_AFTER_END), 4);
#if DEBUG
        printf("Write TESTDATA_CAPTURE_AFTER_END\n");
#endif
        file.close();
        sinfo.clear();
        capture_order.clear();
        
        printf("Capture Closed !\n\n\n\n");

        parent_capture_finish = true;
    }

private:
    std::unordered_map<std::string, unsigned int> var_id_table;
    std::unordered_map<unsigned int, std::string> var_id_resv_table;
    std::unordered_map<std::string, signal_info_t> sinfo;
    std::vector<uint32_t> capture_order;
    int before_capture_order_idx;
    int after_capture_order_idx;
    std::unordered_set<std::string> func_grp;

    static void set_parent_func(const char *func_name) {
        std::string str(func_name);
        std::string toRemove = "_impl";

        size_t pos = str.rfind(toRemove);
        if (pos != std::string::npos) {
            str.erase(pos, toRemove.length());
        }
        if (parent_func.empty()){
            parent_func = str;
        } else if (parent_func == str){
            return;
        } else {
            std::cerr << "Error: multiple set_parent_func() call. existed parent_func:" << parent_func << " parent_func:" << str << '\n';
            exit(-1);
        }
    }

    std::string trim_string(const std::string& str){
        auto start = str.find_first_not_of(" \t\n\r");
        auto end = str.find_last_not_of(" \t\n\r");
        if (start == std::string::npos || end == std::string::npos) {
            return "";
        }
        return str.substr(start, end - start + 1);
    }

    void write_data(const std::string &varname, signal_info_t *siginfo, const void *data, size_t width, size_t qlen){
        const uint8_t *data8 = (const uint8_t*)data;
        capture_marker_t loc;
        loc.is_after_capture = capture_after_flag;
        loc.buf_idx = siginfo->capture_data.size();
        loc.buf_size = width * qlen;
        loc.count_id = get_capture_count();

        auto var_id = var_id_table[varname];

        if (siginfo->capture_marker.size() > 0) {
            //override the last capture data if the same variable is captured again
            capture_marker_t &last_marker = siginfo->capture_marker.back();
            if (capture_after_flag) {
                if (last_marker.is_after_capture == capture_after_flag && last_marker.count_id == loc.count_id) {
                    siginfo->capture_data.erase(siginfo->capture_data.begin() + last_marker.buf_idx, siginfo->capture_data.end());
                    siginfo->capture_marker.pop_back();

                    //remove the last var_id in capture_order
                    auto it = std::find(capture_order.rbegin(), capture_order.rend(), var_id);
    
                    // Check if the item is found
                    if (it != capture_order.rend()) {
                        // Convert reverse iterator to normal iterator
                        auto normalIt = it.base() - 1;
                        // Erase the item from the vector
                        capture_order.erase(normalIt);
                    } else {
                        printf("Unexpected result: cannot find the var_id in capture_order\n");
                        exit(-1);
                    }
                }
            } else {
                if (last_marker.is_after_capture == capture_after_flag && last_marker.count_id == loc.count_id) {
                    //ignore the same variable capture
#if DEBUG || SHOW_CAPTURE_DATA
                    printf("skip capture %s %d %d\n", varname.c_str(), loc.count_id, loc.buf_idx);
#endif
                    return;
                }
            }
        }

        if (capture_after_flag) {
            capture_order.push_back(var_id);
            after_capture_order_idx = capture_order.size() - 1;
        } else {

            
            if(siginfo->capture_marker.size() > 0 ) {
                uint32_t prev_var_id = capture_order.back();

                unsigned int prev_count_id = sinfo[var_id_resv_table[prev_var_id]].capture_marker.back().count_id;

                if (loc.count_id > prev_count_id) {
                    before_capture_order_idx = capture_order.size() - 1;
                    //printf(">> before_capture_order_idx:%d\n", before_capture_order_idx);
                }
            }

            //get last item of capture_order
            if (capture_order.size() == 0) {
                capture_order.push_back(var_id);
                before_capture_order_idx = 0;
            } else {
                capture_order.insert(capture_order.begin() + before_capture_order_idx + 1, var_id);
                ++before_capture_order_idx;
            }
            //printf("before_capture_order_idx:%d\n", before_capture_order_idx);
        }

        for(size_t i=0; i<width * qlen; i++){
            siginfo->capture_data.push_back(data8[i]);
        }
        siginfo->capture_marker.push_back(loc);


#if DEBUG || SHOW_CAPTURE_DATA
        size_t imax = std::min(width * qlen, (size_t)16);
        for(size_t i=0; i<imax; i++){
            printf("%02X ", data8[i]);
        }
        printf("\n");
#endif
        siginfo->width = width;
    }


    uint32_t capture_count;
    bool capture_after_flag;
    std::string filepath;
    bool parent_func_flag;
    unsigned int var_idx_cnt;

    static std::string parent_func;
    bool inside_parent_func;
    static std::atomic<unsigned int> parent_capture_count;
    static std::atomic<bool> parent_capture_finish;

    //Show the warning message only once
    //if dedicated variable is found inside warn_msg, do not show any more. 
    static std::unordered_set<std::string> warn_msg;
};

class tgcapture_dma{
public:
    tgcapture_dma(const char *filepath) {
        file = fopen(filepath, "wb");
        if (file == NULL) {
            printf("cannot open file for dma capture\n");
            exit(-1);
        }
    }

    ~tgcapture_dma(){
        if (file != NULL){
            fclose(file);
            file = NULL;
        }
    }

    void dma_start(){
        //printf("tgcapture_dma start\n");
        dma_data.clear();
    }

    void dump(uint8_t src){
        dma_data.push_back(src);
    }

    void dma_stop(){
        uint32_t dma_size = dma_data.size();
        fwrite(&dma_size, 4, 1, file);
        fwrite(dma_data.data(), 1, dma_size, file);
        printf("tgcapture_dma dump %u bytes\n", dma_size);
        dma_data.clear();
    }

private:
    FILE *file;
    std::vector<uint8_t> dma_data;
};


//------------------------------------------------------------------------------------

//specialized for struct type
template<typename T>
void override_capture(CCapture &cap, enum CCapture::CAPTURE_STATUS mode, const std::string& func_name, const std::string& var_name, T &mv);

#define QUOTE(...) #__VA_ARGS__


std::string filename_append_tidx(const std::string &filename);

#define tgOpen(filepath, ...)                                                       \
        std::string argvstr = QUOTE(__VA_ARGS__);                                   \
        std::istringstream argvstr_ss(argvstr);                                     \
        if (!capture->is_inited(__func__)) {                                        \
            if (parent_func_status == PARENT_FUNC_MATCHED) {                        \
                capture->set_logfile(filename_append_tidx(filepath));               \
                capture->init_var(__func__, argvstr_ss, ##__VA_ARGS__);             \
            } else if (parent_func_status == PARENT_FUNC_NOT_MATCHED) {             \
                capture->init_var(__func__, argvstr_ss, ##__VA_ARGS__);             \
            } else {                                                                \
                capture->set_logfile(filepath);                                     \
                capture->init_var(__func__, argvstr_ss, ##__VA_ARGS__);             \
            }                                                                       \
        }


#define tgCaptureBeforeCall(...) do {                                               \
        if (capture->get_capture_count() < MAX_CAPTURE_COUNT) {                     \
            std::string argvstr = QUOTE(__VA_ARGS__);                               \
            std::istringstream argvstr_ss(argvstr);                                 \
            capture->mark_capture_before();                                         \
            capture->capture(__func__, argvstr_ss, ##__VA_ARGS__);                  \
        }                                                                           \
    } while (0);

#define tgCaptureAfterCall(...) do {                                              \
        if (capture->get_capture_count() < MAX_CAPTURE_COUNT){                    \
            std::string argvstr = QUOTE(__VA_ARGS__);                             \
            std::istringstream argvstr_ss(argvstr);                               \
            capture->mark_capture_after();                                        \
            capture->capture(__func__, argvstr_ss, ##__VA_ARGS__);                \
            capture->inc_capture_count(__func__);                                 \
        }                                                                         \
    } while (0);


#define tgClose()

#endif
