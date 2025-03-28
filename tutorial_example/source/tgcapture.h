#ifndef _TGCAPTURE_H_
#define _TGCAPTURE_H_

#if CAPTURE_COSIM

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
#include <mutex>
#include "tgcommon.h"

#include "common_with_hls.h"
#include "xmem.h"

//#define DEBUG 1
//#define SHOW_CAPTURE_DATA         1
#define CAPTURE_SHORT_SIGNAME     1

enum LOG_DATA_MODE {
    LOG_RAW_DATA,
    LOG_CRC_DATA
};

typedef struct {
	bool is_after_capture;
    enum LOG_DATA_MODE log_data_mode;
    unsigned int buf_idx;
    unsigned int buf_size;
    unsigned int count_id;
} capture_marker_t;

typedef struct signal_info{
    unsigned int width;
    datatype_t datatype;
    std::vector<uint8_t> capture_data;          //Save the actual data byte
    std::vector<capture_marker_t> capture_marker;
    uint32_t flush_file_idx;

    signal_info(){
        width = 0;
        datatype = UNKNWON_TYPE;
        flush_file_idx = 0;
    }

    void clear_data() {
        capture_data.clear();
        capture_marker.clear();
        flush_file_idx = 0;
    }
}signal_info_t;

class CCapture;

uint32_t crc32(const uint8_t *data, size_t length);
std::string filename_append_tidx(const std::string &filename);
std::string filename_append_partid(const std::string &filename, int partnum);
extern const char *CONSOLE_YELLOW;
extern const char *CONSOLE_NONE;


//------------------------------------------------------------------------------------

// Custom key structure combining pthread_t and std::string
struct CaptureGrpKey {
    pthread_t tid;
    std::string func_name;

    // Constructor
    CaptureGrpKey(pthread_t thread_id, const std::string& function_name) 
        : tid(thread_id), func_name(function_name) {}

    CaptureGrpKey(pthread_t thread_id, const char *function_name) 
        : tid(thread_id), func_name(function_name) {}

    // Equality operator
    bool operator==(const CaptureGrpKey& other) const {
        return pthread_equal(tid, other.tid) && func_name == other.func_name;
    }
};

struct capture_cabac_info{
    FILE* f;
    bool enable;
    unsigned int count;

    capture_cabac_info(){
        f= NULL;
        enable = false;
        count = 0;
    }
    capture_cabac_info(FILE* p_f, bool p_enable){
        f= p_f;
        enable = p_enable;
        count = 0;
    }
};

//------------------------------------------------------------------------------------

class CCabacLog{
public:
    ~CCabacLog(){
        close();
    }

    FILE * create_file(const std::string &func_name){
        std::string filename = func_name;
        filename.append("_decode_bin.dat");
        filename = filename_append_tidx(filename);
        FILE *fp = fopen(filename.c_str(), "wb");
        if (!fp) {
            printf("Cannot create file for cabac %s", filename.c_str());
            exit(-1);
        }
        return fp;
    }

    void enable_cabac(CaptureGrpKey key){
        std::lock_guard<std::mutex> lock(mtx);
        auto iter = fbin.find(key.tid);
        if (iter == fbin.end()){
            std::unordered_map<std::string, capture_cabac_info> cabac_map;
            FILE *fp = create_file(key.func_name);
            capture_cabac_info cabac_info(fp, true);
            cabac_map.insert(std::make_pair(key.func_name, cabac_info));
            fbin.insert(std::make_pair(key.tid, cabac_map));
            //printf("enable_cabac: create tid %d %s\n", key.tid, key.func_name.c_str());
        } else {
            auto & cabac_map = iter->second;
            auto iter2 = cabac_map.find(key.func_name);
            if (iter2 == cabac_map.end()){
                FILE *fp = create_file(key.func_name);
                capture_cabac_info cabac_info(fp, true);
                cabac_map.insert(std::make_pair(key.func_name, cabac_info));
                //printf("enable_cabac: insert cabac_map %d %s\n", key.tid, key.func_name.c_str());
            } else {
                iter2->second.enable = true;
                //printf("enable_cabac: %d %s %d\n", key.tid, key.func_name.c_str(), iter2->second.count);
            }
        }
    }

    void disable_cabac(CaptureGrpKey key){
        std::lock_guard<std::mutex> lock(mtx);
        auto iter = fbin.find(key.tid);
        if (iter == fbin.end()){
            printf("Error: disable_cabac cannot find tid\n");
            exit(-1);
        }
        auto & cabac_map = iter->second;
        auto iter2 = cabac_map.find(key.func_name);
        if (iter2 == cabac_map.end()){
            printf("Error: disable_cabac cannot find function name in cabac_map\n");
            exit(-1);
        }

        iter2->second.enable = false;
        //printf("disable cabac : %d %s\n", key.tid, key.func_name.c_str());
    }

    void close(){
        for(auto &item : fbin){
            for (auto & cabac_item : item.second){
                
                FILE * fp = cabac_item.second.f;
                if (fp != NULL) {
                    fclose(fp);
                    cabac_item.second.f = NULL;
                }
            }
        }
    }


    void log_data(int ctx, int bin){
        std::lock_guard<std::mutex> lock(mtx);
        pthread_t tid = pthread_self();
        auto iter = fbin.find(tid);
        if (iter == fbin.end()){
            return;
        }
    
        auto & cabac_map = iter->second;
    
        for (auto &item : cabac_map) {
            auto & finfo = item.second;
            if (finfo.f != NULL && finfo.enable){
                //fputc(ctx & 0xff, outF);
                //fputc((ctx >> 8) & 0xff, outF);
                fputc(bin, finfo.f);
                ++item.second.count;
            }
        }
    }

private:
    std::unordered_map<pthread_t, std::unordered_map<std::string, capture_cabac_info>> fbin;
    std::mutex mtx;
};

//------------------------------------------------------------------------------------


// Custom hash function for CaptureGrpKey
namespace std {
    template<>
    struct hash<CaptureGrpKey> {
        std::size_t operator()(const CaptureGrpKey& k) const {
            std::size_t h1 = std::hash<std::string>{}(k.func_name);
            std::size_t h2 = std::hash<pthread_t>{}(k.tid);
            return h1 ^ h2; // Combine hashes
        }
    };
}

class CCaptureGroup{
public:
    void create_if_not_exist(const CaptureGrpKey &key, bool is_parent_func);
    void set_inside_parent_func(const CaptureGrpKey &key, bool inside);
    bool is_capture_func(const std::string &func_name);
    void get_capture_list(const std::string &func_name, std::unordered_set<CCapture*>& capture_list);

    CCaptureGroup();
    ~CCaptureGroup();

   // Delete copy constructor and copy assignment operator
   CCaptureGroup(const CCaptureGroup&) = delete;            // Disable copy constructor
   CCaptureGroup& operator=(const CCaptureGroup&) = delete; // Disable copy assignment
private:
    std::unordered_map<CaptureGrpKey, CCapture*> items;
    //pthread_mutex_t mtx;
    std::mutex mtx;
    std::vector<std::string> func_list;
    std::unordered_map<pthread_t, std::vector<std::string>> parent_func_stack;
    std::unordered_set<std::string> parent_func_set;
};    


extern CCaptureGroup capture_group;

extern const unsigned int MAX_CAPTURE_COUNT;

class CCapture {
public:
    enum CAPTURE_STATUS{
        ON_OPEN,
        ON_CAPTURE
    };

public:
    CCapture(){
        CCapture(NULL, false);
    }

    CCapture(const char *func_name, bool parent_flag){
        split_file_id = 0;
        var_idx_cnt = 0;
        capture_count = 0;
        capture_after_flag = false;
        inside_parent_func = false;

        before_capture_order_idx = -1;
        after_capture_order_idx = -1;

        indv_capture_count = 0;
        parent_func_flag = parent_flag;
        accumulate_byte_cnt = 0;
        capture_func_name = func_name;        
    }

    ~CCapture(){
        close();
    }

    inline unsigned int get_capture_count(){
        return acc_capture_count[capture_func_name];
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

    // Variadic template function to handle multiple variables
    template <typename T, typename... Args>
    typename std::enable_if<!std::is_class<T>::value, void>::type
    init_var(const std::string &func_name, std::istringstream &paralist_str, const T &data, Args&&... args){
        if (!parent_func_flag && func_name != capture_func_name) {
            return;
        }

        std::string varname;
        std::getline (paralist_str, varname, ',');

#if CAPTURE_SHORT_SIGNAME
        varname = trim_string(varname);
#else
        varname = func_name + "." + trim_string(varname);
#endif

#if DEBUG || SHOW_CAPTURE_DATA
        std::cout << "init_var:T:" << func_name << ',' << (int)get_datatype(data) << ' ' << varname << ' ' << sizeof(data)<< '\n';
#endif

        if (parent_func_flag) {
            if ((func_name.compare(capture_func_name) != 0) && varname.compare("ans") == 0){
                init_var(func_name, paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
                return;
            }
        }

        if (varname.empty()){
            init_var(func_name, paralist_str, std::forward<Args>(args)...); // Recursively dump the remaining variables
            return;
        }

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
        if (!parent_func_flag && func_name != capture_func_name) {
            return;
        }

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
    

    bool is_done(){
        return  !(get_capture_count() < MAX_CAPTURE_COUNT);
    }

    const std::string & get_function_name(){
        return capture_func_name;
    }

    void mark_capture_before(){
        capture_after_flag = false;
    }

    void mark_capture_after(){
        capture_after_flag = true;
    }

    void inc_capture_count(const char *func_name){
        if (func_name == capture_func_name){
            static std::mutex mtx_cnt;
            std::lock_guard<std::mutex> lock(mtx_cnt);
            ++acc_capture_count[capture_func_name];
            ++indv_capture_count;
        }
#if DEBUG || SHOW_CAPTURE_DATA
        printf("============ capture_count: %s %d %d ============\n", func_name, acc_capture_count[capture_func_name], capture_count);
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
                    << ",count:" << acc_capture_count[capture_func_name] << ',' << indv_capture_count << '\n';
#endif
        signal_info_t &siginfo = sinfo[varname];

        write_data(varname, &siginfo, (const void*)&value[0], sizeof(T), N);

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
                    << ",count:" << acc_capture_count[capture_func_name] << ',' << indv_capture_count << '\n';
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

        if ((func_name.compare(capture_func_name) != 0) && varname.compare("ans") == 0){
            capture(func_name, sn, std::forward<Args>(args)...);
            return;
        }


#if DEBUG || SHOW_CAPTURE_DATA
        std::cout   << "capture:native:" << (capture_after_flag ? 'e' : 's')    \
                    << "type:" << (int)get_datatype(value) << ','               \
                    << varname << ",size:" << sizeof(T)                         \
                    << ",count:" << acc_capture_count[capture_func_name] << ',' << indv_capture_count << '\n';
#endif
        signal_info_t &siginfo = sinfo[varname];

        write_data(varname, &siginfo, (const void*)&value, sizeof(value), 1);

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
                    << ",count" << acc_capture_count[capture_func_name] << ',' << indv_capture_count << '\n';
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
            write_data(varname, &siginfo, (const void*)value, sizeof(*value), num_elements);
        }
        capture(func_name, sn, std::forward<Args>(args)...);
    }

    bool is_buffer_almost_full(){
#if 1
        return accumulate_byte_cnt > 1024*1024*1024;    //1GB
#else   
        return accumulate_byte_cnt > 10*1024*1024;      //10MB, for debug purpose
#endif
    }

    void close(){
        if (accumulate_byte_cnt == 0){
            return ;
        }

    	write_file();
        printf("Capture Closed !\n\n\n\n");
    }

    void split_file(){
        if (accumulate_byte_cnt == 0){
            return ;
        }
        ++split_file_id;
        write_file();
    }

    void write_file(){
        printf("%s",CONSOLE_YELLOW);
        printf("=== write_file\n");
        printf("%s", CONSOLE_NONE);
        if (sinfo.size() == 0){
            return ;
        }

        if(parent_func_flag){
            printf("*** Capture Parent and Child function ***\n");
        }

        const std::string &new_filename = filename_append_partid(filepath, split_file_id);

        std::ofstream file(new_filename, std::ios::binary);
        std::cout << CONSOLE_YELLOW << "write file to " << new_filename << CONSOLE_NONE <<'\n';

        uint32_t num = 0;
        for (auto & s : sinfo) {
            //std::cout << "---" << s.first << '\n';
            if (s.second.capture_data.size() != 0) {
                std::cout << s.first << " size:" << s.second.capture_data.size() <<'\n';
                num++;
            }
        }

        const char file_signature[] = {'T', 'B', '0', '1'};
        file.write(file_signature, sizeof(file_signature));
        file.write(reinterpret_cast<const char*>(&num), sizeof(num));

        std::cout << "capture count:" << indv_capture_count << '\n';

        printf("capture signal number: %u\n\n", num);

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

            if (info.flush_file_idx >= info.capture_marker.size()){
                std::cerr << "unexpected error in flush_file_idx " << var_name << ',' << info.flush_file_idx << ',' <<  info.capture_marker.size() << '\n';
                exit(-1);
            }
            const capture_marker_t &marker = info.capture_marker[info.flush_file_idx];

            bool is_after_capture = marker.is_after_capture;
            unsigned int count_id = marker.count_id;
            LOG_DATA_MODE log_data_mode = marker.log_data_mode;

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
            if(log_data_mode == LOG_CRC_DATA) {
                uint32_t buf_size_tag = marker.buf_size | 0x80000000;
                file.write(reinterpret_cast<const char*>(&buf_size_tag), 4);
                file.write(reinterpret_cast<const char*>(info.capture_data.data() + marker.buf_idx), marker.buf_size);
            } else {
                file.write(reinterpret_cast<const char*>(&marker.buf_size), 4);
                file.write(reinterpret_cast<const char*>(info.capture_data.data() + marker.buf_idx), marker.buf_size);
            }
            info.flush_file_idx++;
        }

        //Add the marker to indicate the end of the capture (after) data
        file.write(reinterpret_cast<const char*>(&TESTDATA_CAPTURE_AFTER_END), 4);
#if DEBUG
        printf("Write TESTDATA_CAPTURE_AFTER_END\n");
#endif
        file.flush();

        if (file.fail()){
            std::cerr << new_filename << " write to disk failed\n";
            exit(-1);
        }

        file.close();


        for (auto & item : sinfo) {
            item.second.clear_data();
        }

        capture_order.clear();
        before_capture_order_idx = -1;
        after_capture_order_idx = -1;
        func_grp.clear();
        accumulate_byte_cnt = 0;
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

    void write_data(const std::string &varname, signal_info_t *siginfo, const void *data, size_t width, size_t qlen){
        const uint8_t *data8 = (const uint8_t*)data;
        capture_marker_t loc;
        loc.is_after_capture = capture_after_flag;
        loc.count_id = get_capture_count();

        siginfo->width = width;

        auto var_id_iter = var_id_table.find(varname);
        if (var_id_iter == var_id_table.end()){
            printf("Unexpect error: varname %s cannot be found.\n", varname.c_str());
            exit(-1);
        }

        unsigned int var_id = var_id_iter->second;

        if (!siginfo->capture_marker.empty()) {
            //override the last capture data if the same variable is captured again
            capture_marker_t &last_marker = siginfo->capture_marker.back();
            if (capture_after_flag) {
                if (last_marker.is_after_capture == capture_after_flag && last_marker.count_id == loc.count_id) {
                    siginfo->capture_data.erase(siginfo->capture_data.begin() + last_marker.buf_idx, siginfo->capture_data.end());
                    accumulate_byte_cnt -= last_marker.buf_size;
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
                    printf("skip capture %s %d\n", varname.c_str(), loc.count_id);
#endif
                    return;
                }
            }
        }

        if (capture_after_flag) {
            capture_order.push_back(var_id);
            after_capture_order_idx = capture_order.size() - 1;
        } else {
            if(!siginfo->capture_marker.empty()) {
                uint32_t prev_var_id = capture_order.back();

                unsigned int prev_count_id = sinfo[var_id_resv_table[prev_var_id]].capture_marker.back().count_id;

                if (loc.count_id > prev_count_id) {
                    before_capture_order_idx = capture_order.size() - 1;
                    //printf(">> before_capture_order_idx:%d\n", before_capture_order_idx);
                }
            }

            //get last item of capture_order
            if (capture_order.empty()) {
                capture_order.push_back(var_id);
                before_capture_order_idx = 0;
            } else {
                capture_order.insert(capture_order.begin() + before_capture_order_idx + 1, var_id);
                ++before_capture_order_idx;
            }
            //printf("before_capture_order_idx:%d\n", before_capture_order_idx);
        }

        if ((width * qlen > 512) && capture_after_flag) {
            loc.log_data_mode = LOG_CRC_DATA;
            loc.buf_idx = siginfo->capture_data.size();
            loc.buf_size = 4;

            siginfo->capture_marker.push_back(loc);

            uint32_t crc_value = crc32(data8, width*qlen);

#if DEBUG || SHOW_CAPTURE_DATA
            size_t imax = width * qlen;
            //size_t imax = std::min(width * qlen, (size_t)16);
            
            if (imax > 512) {
                printf("=== show capture data: %s (crc: %08X)===\n", varname.c_str(), crc32(data8, imax));
            } else {
                printf("=== show capture data: %s ===\n", varname.c_str());
            }

            imax = std::min(width * qlen, (size_t)16);
            for(size_t i=0; i<imax; i++){
                printf("%02X ", data8[i]);

                if ((i+1) % 16 == 0) {
                    printf("\n");
                }
            }
            printf("\n");
#endif



#if DEBUG || SHOW_CAPTURE_DATA
            printf("%s crc:%x size:%zu\n", varname.c_str(), crc_value, width*qlen);
#endif
            siginfo->capture_data.push_back(crc_value & 0xff);
            siginfo->capture_data.push_back((crc_value >> 8) & 0xff);
            siginfo->capture_data.push_back((crc_value >> 16) & 0xff);
            siginfo->capture_data.push_back((crc_value >> 24) & 0xff);
            accumulate_byte_cnt += 4;
            return;
        }


        loc.buf_idx = siginfo->capture_data.size();
        loc.buf_size = width * qlen;
        loc.log_data_mode = LOG_RAW_DATA;
        siginfo->capture_marker.push_back(loc);

#if 1
        for(size_t i=0; i<width * qlen; i++){
            siginfo->capture_data.push_back(data8[i]);
        }
#else
        //printf("len:%d\n", width * qlen);
        size_t old_size = siginfo->capture_data.size();
        siginfo->capture_data.resize(old_size + (width * qlen));

        memcpy(siginfo->capture_data.data() + old_size, data8, width * qlen);
        //printf("%d %d\n", siginfo->capture_data.size(), width * qlen);
#endif
        accumulate_byte_cnt += width * qlen;




#if DEBUG || SHOW_CAPTURE_DATA
        size_t imax = width * qlen;
        //size_t imax = std::min(width * qlen, (size_t)16);

        if (imax > 512) {
            printf("=== show capture data: %s (crc: %08X)===\n", varname.c_str(), crc32(data8, imax));
        } else {
            printf("=== show capture data: %s ===\n", varname.c_str());
        }

        imax = std::min(width * qlen, (size_t)16);
        for(size_t i=0; i<imax; i++){
            printf("%02X ", data8[i]);

            if ((i+1) % 16 == 0) {
                printf("\n");
            }
        }
        printf("\n");
#endif
    }

private:
    inline void set_inside_parent_func(bool flag){
        inside_parent_func = flag;
    }
    friend class CCaptureGroup;

private:
    std::unordered_map<std::string, unsigned int> var_id_table;
    std::unordered_map<unsigned int, std::string> var_id_resv_table;
    std::unordered_map<std::string, signal_info_t> sinfo;
    std::vector<uint32_t> capture_order;
    int before_capture_order_idx;
    int after_capture_order_idx;
    std::unordered_set<std::string> func_grp;

    int split_file_id;
    uint32_t accumulate_byte_cnt;
    uint32_t capture_count;
    bool capture_after_flag;
    std::string filepath;
    bool parent_func_flag;
    unsigned int var_idx_cnt;

    std::string capture_func_name;
    bool inside_parent_func;
    unsigned int indv_capture_count;
    static std::unordered_map<std::string, unsigned int> acc_capture_count;

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

#define tgOpen(...)                                                             \
        std::string argvstr = QUOTE(__VA_ARGS__);                               \
        for(auto capture : capture_list) {                                      \
            std::istringstream argvstr_ss(argvstr);                             \
            if (!capture->is_inited(__func__)) {                                \
                capture->init_var(__func__, argvstr_ss, ##__VA_ARGS__);         \
            }                                                                   \
        }


#define tgCaptureBeforeCall(...)    do {                                        \
        std::string argvstr = QUOTE(__VA_ARGS__);                               \
        for(auto capture : capture_list) {                                      \
            std::istringstream argvstr_ss(argvstr);                             \
            capture->mark_capture_before();                                     \
            capture->capture(__func__, argvstr_ss, ##__VA_ARGS__);              \
        }                                                                       \
    } while (0);

#define tgCaptureAfterCall(...) do {                                            \
        std::string argvstr = QUOTE(__VA_ARGS__);                               \
        for(auto capture : capture_list) {                                      \
            std::istringstream argvstr_ss(argvstr);                             \
            capture->mark_capture_after();                                      \
            capture->capture(__func__, argvstr_ss, ##__VA_ARGS__);              \
            capture->inc_capture_count(__func__);                               \
        }                                                                       \
    } while (0);


#define tgClose()  for (auto capture : capture_list) {          \
                      if(capture->is_buffer_almost_full()) {    \
                          capture->split_file();                \
                      }                                         \
                  }

#endif //#if CAPTURE_COSIM

#endif
