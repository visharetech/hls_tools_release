# Get the current script file
set currentScript [info script]

# Get the current directory
set currentDir [file normalize [file dirname $currentScript]]

# Get a list of Tcl files in the current directory
set tclFiles [glob -nocomplain -directory $currentDir *.tcl]

# Remove the current script file from the list
set tclFiles [lsearch -inline -all -not -exact $tclFiles $currentScript]

# Iterate through the Tcl files and execute them
foreach file $tclFiles {
    puts "Executing $file"
    
    # Execute the source file using catch
    set result [catch {source $file} errorInfo]

    # Check if an error occurred
    if {$result != 0} {
        # Display the error message
        puts "Error: $errorInfo"
    } else {
        # Source file executed successfully
        puts "Source file executed successfully"
    }
}