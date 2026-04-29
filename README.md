# check-dir-file-age
Nagios / Icinga plugin to monitor the age of the newest or oldest file in a directory. This plugin is distinct from the standard `check_file_age` plugin shipped with monitoring-plugins, which checks a single specific file by path. `check_dir_file_age.sh` scans an entire directory and selects either the newest or oldest file automatically. 
