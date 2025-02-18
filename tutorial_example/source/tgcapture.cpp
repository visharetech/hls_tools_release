#include <vector>
#include "tgcapture.h"


//static CCapture member variable
std::unordered_set<std::string> CCapture::warn_msg;
std::string CCapture::parent_func;

std::atomic<unsigned int> CCapture::parent_capture_count(0);
std::atomic<bool> CCapture::parent_capture_finish(false);

CCaptureGroup::~CCaptureGroup(){
    for ( auto item : items){
        item.second->close();

        if (item.second != NULL) {
            delete item.second;
            item.second = NULL;
        }
    }
}

CCaptureGroup capture_group;

//specialized for struct type
template<typename T>
void override_capture(CCapture &cap, enum CCapture::CAPTURE_STATUS mode, const std::string &func_name, const std::string& var_name, T &mv){
    std::cout << "capture func should specialized " << var_name << ',' << sizeof(T) <<'\n';
    exit(-1);
}


int thread_idx_to_seq_id(pthread_t thread_id) {
    static std::unordered_map<pthread_t, int> seq_id_map;
    static int index = 0;

    auto iter = seq_id_map.find(thread_id);
    if (iter == seq_id_map.end()) {
        int seq_id = index++;
        seq_id_map.insert({thread_id, seq_id});
        return seq_id;
    } else {
        return iter->second;
    }
}

std::string filename_append_tidx(const std::string &filename){
    //insert the thread idx before the file extension
    std::stringstream ss;
    pthread_t tid = pthread_self();

    int seq_id = thread_idx_to_seq_id(tid);

    if (seq_id == 0){
    	return filename;
    }

    const char *dot = strrchr(filename.c_str(), '.');
    if (dot == NULL){
        ss << filename << "_" << seq_id;
        return ss.str();
    }

    int len = dot - filename.c_str();
    ss.write(filename.c_str(), len);
    ss << "_" << seq_id;
    ss.write(dot, strlen(dot));
    //std::cout << "new filename:" << ss.str() << '\n';
    
    return ss.str();
}

#if 1
//specialized for tutorial example vector_2d
template<> void override_capture<const vector_2d>(CCapture &cap, enum CCapture::CAPTURE_STATUS mode, const std::string &func_name, const std::string& var_name,  const vector_2d &vec)
{
    if (mode == CCapture::ON_OPEN){
        std::stringstream inner_ss;
        inner_ss << var_name << "_x,";
        inner_ss << var_name << "_y,";

        std::istringstream inner_iss(inner_ss.str());

        cap.init_var(func_name, inner_iss, vec.x, vec.y);

    }
    else if (mode == CCapture::ON_CAPTURE) {
        std::stringstream inner_ss;

        inner_ss << var_name << "_x,";
        inner_ss << var_name << "_y,";

        std::istringstream inner_iss(inner_ss.str());

        cap.capture(func_name, inner_iss, vec.x, vec.y);
    }
}

#endif


template<> void override_capture<const xmem_t>(CCapture &cap, enum CCapture::CAPTURE_STATUS mode, const std::string &func_name, const std::string& var_name,  const xmem_t &xmem)
{
    //no need to capture xmem data
}

template<> void override_capture<const child_cmd_t>(CCapture &cap, enum CCapture::CAPTURE_STATUS mode, const std::string &func_name, const std::string& var_name,  const child_cmd_t &cmd)
{
    if (mode == CCapture::ON_OPEN){
        std::stringstream inner_ss;
        inner_ss << var_name << "_id,";
        inner_ss << var_name << "_param,";

        std::istringstream inner_iss(inner_ss.str());

        cap.init_var(func_name, inner_iss, cmd.id, cmd.param);

    }
    else if (mode == CCapture::ON_CAPTURE) {
        std::stringstream inner_ss;

        inner_ss << var_name << "_id,";
        inner_ss << var_name << "_param,";

        std::istringstream inner_iss(inner_ss.str());

        cap.capture(func_name, inner_iss, cmd.id, cmd.param);
    }
}
