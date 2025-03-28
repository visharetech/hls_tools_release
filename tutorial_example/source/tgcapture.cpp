#if CAPTURE_COSIM
#include <vector>
#include "tgcapture.h"


//static CCapture member variable
std::unordered_set<std::string> CCapture::warn_msg;

std::unordered_map<std::string, unsigned int> CCapture::acc_capture_count;

const char *CONSOLE_YELLOW = "\033[33m";
const char *CONSOLE_NONE = "\033[0m";

CCaptureGroup::CCaptureGroup(){
    //pthread_mutex_init(&mtx, NULL);
}

void CCaptureGroup::create_if_not_exist(const CaptureGrpKey &key, bool is_parent_func){
    std::lock_guard<std::mutex> lock(mtx);
    auto iter = capture_group.items.find(key);
    if (iter == capture_group.items.end()){
        CCapture *capture = new CCapture(key.func_name.c_str(), is_parent_func);
        std::string filepath = key.func_name;
        filepath.append("_output.bin");
        capture->set_logfile(filename_append_tidx(filepath));
        capture_group.items[key] = capture;
    }
}

void CCaptureGroup::set_inside_parent_func(const CaptureGrpKey &key, bool inside){
    std::lock_guard<std::mutex> lock(mtx);
    items[key]->set_inside_parent_func(inside);

    if (inside){
        auto tid_it = parent_func_stack.find(key.tid);
        if (tid_it == parent_func_stack.end()){
            std::vector<std::string> vec;
            vec.emplace_back(key.func_name);
            parent_func_stack[key.tid] = vec;
        } else {
            tid_it->second.push_back(key.func_name);
        }
    } else {
        auto tid_it = parent_func_stack.find(key.tid);
        if (tid_it == parent_func_stack.end()){
            printf("error: Cannot find the tid in parent_func_stack");
            exit(-1);
        }
        
        tid_it->second.pop_back();
    }
}

bool CCaptureGroup::is_capture_func(const std::string & current_func_name){
    //check whether it is inside capture func
    std::lock_guard<std::mutex> lock(mtx);
    pthread_t self_tid = pthread_self();

    //check whether parent_func_stack contains element
    auto iter = parent_func_stack.find(self_tid);
    if (iter == parent_func_stack.end()){
        return false;
    }
    if(!iter->second.empty()) {
        return true;
    }

    //check whether it is in items
    CaptureGrpKey key(self_tid, current_func_name);
    auto iter2 = items.find(key);
    if (iter2 != items.end()) {
        return true;
    }
    return false;
}

void CCaptureGroup::get_capture_list(const std::string & current_func_name, std::unordered_set<CCapture*>& capture_list){
    //capture_list.clear();
    std::lock_guard<std::mutex> lock(mtx);
    pthread_t self_tid = pthread_self();
    auto iter = parent_func_stack.find(self_tid);
    if (iter != parent_func_stack.end()){
        for(auto &func_name : iter->second) {
            CaptureGrpKey key(self_tid, func_name);
            CCapture * capture = items[key];
            if (!capture->is_done()){
                capture_list.insert(capture);
            }
        }
    }

    CaptureGrpKey key(self_tid, current_func_name);
    auto iter2 = items.find(key);
    if (iter2 != items.end()) {
        if (!iter2->second->is_done()){
            capture_list.insert(iter2->second);
        }
    }
    //printf("capture_list size:%d\n", capture_list.size());
}

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

static pthread_mutex_t tid_mtx = PTHREAD_MUTEX_INITIALIZER;

int thread_idx_to_seq_id(pthread_t thread_id) {
    static std::unordered_map<pthread_t, int> seq_id_map;
    static int index = 0;

    pthread_mutex_lock(&tid_mtx);

    auto iter = seq_id_map.find(thread_id);
    if (iter == seq_id_map.end()) {
        int seq_id = index++;
        seq_id_map.insert({thread_id, seq_id});
        pthread_mutex_unlock(&tid_mtx);
        return seq_id;
    } else {
        pthread_mutex_unlock(&tid_mtx);
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
        ss << filename << "_tid" << seq_id;
        return ss.str();
    }

    int len = dot - filename.c_str();
    ss.write(filename.c_str(), len);
    ss << "_tid" << seq_id;
    ss.write(dot, strlen(dot));
    //std::cout << "new filename:" << ss.str() << '\n';
    
    return ss.str();
}

std::string filename_append_partid(const std::string &filename, int partnum){
    //insert the part id before the file extension
    std::stringstream ss;

    if (partnum == 0){
    	return filename;
    }

    const char *dot = strrchr(filename.c_str(), '.');
    if (dot == NULL){
        ss << filename << ".part" << partnum;
        return ss.str();
    }

    int len = dot - filename.c_str();
    ss.write(filename.c_str(), len);
    ss << ".part" << partnum;
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
#endif

