# copy_rtl   : Set as 1 if need to copy to destination directory.
# dest       : Destination of HLS RTL code.
# hls_file   : hls source file path
# hls_func_list.txt : HLS functions

set copy_rtl  1

source hls.cfg

set file_handle [open "hls_func_list.txt" r]

#Create directory prj
set dirname "prj"
if {![file exists $dirname]} {
    file mkdir $dirname
}

while {[gets $file_handle line] != -1} {
  # Ignore lines starting with "#"
  if {[string index $line 0] eq "#"} {
    continue
  }
  
  # Split the line into parameters separated by spaces or tabs
  set params [regexp -all -inline {\S+} $line]
  
  # Check if the line contains exactly 5 parameters
  if {[llength $params] != 5} {
    return -code 1 "Error: Line does not contain exactly 5 parameters"
  }
  
  set func_name     [lindex $params 0]
  set copy_rtl      [lindex $params 1]
  set ap_ce         [lindex $params 2]
  set decBin_itf    [lindex $params 3]
  set hcache        [lindex $params 4]
  
  
  puts "************************************"
  puts "func_name  : $func_name"
  puts "hls_exec   : $hls_exec"
  puts "copy_rtl   : $copy_rtl"
  puts "ap_ce      : $ap_ce"
  puts "decBin_itf : $decBin_itf"
  puts "hcache     : $hcache"
  
  source hls.tcl
  if {$decBin_itf == 1} {
  	exec add_decBin_itf.bat ${func_name}
  }

  # hls_exec == 0: csim, no rtl is generated
  if {$copy_rtl == 1 && $hls_exec > 0} {
    puts "Copy ${func_name} RTL to $dest"
    
    if {![file isdirectory ${dest}]} {
        # Create the directory if not exist
        puts "create directory: $dest"
        file mkdir ${dest}
    }

    set current_dir [pwd]
    puts "current_dir: $current_dir"

    #Copy file to dest
  	#exec cp $current_dir/prj/${func_name}_sol/syn/verilog/* ${dest}/
  	set files [glob -nocomplain ${current_dir}/prj/${func_name}_sol/syn/verilog/*]
  	foreach file $files {
  	   set baseName [file tail $file]
  	   set destPath "$dest/$baseName"
  	   file copy -force $file $destPath
  	}
  }
}

exit
