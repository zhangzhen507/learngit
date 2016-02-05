#!/bin/bash

source log.sh /var/log/pageserver.log

send()
{
	ip=$1
	port=$2
	msg=$3
	while true; do
		echo $msg | nc $ip $port
		[ $? -eq 0 ] && return
	done
}

receive()
{
	port=$1
	echo $(nc -lp $port)
}


get_full_path()
{       
        relative_dir=$1
        pwd_dir=$(pwd)
	relative_dir=${relative_dir%/}
        if [[ "$relative_dir" =~ ^[a-z_0-9][a-z_0-9]* ]]; then
                echo ${pwd_dir}/${relative_dir}
                return 0
        fi
        if [[ $relative_dir =~ ^./* ]]; then
                relative_dir=${relative_dir#./}
        fi
        while [[ ${relative_dir} =~ '../' ]]; do
                relative_dir=${relative_dir#../}
                pwd_dir=${pwd_dir%/*}
        done 
        if [ -n $pwd_dir ]; then
                echo $pwd_dir/$relative_dir
                return 0
        else    
                echo /$relative_dir
                return 0
        fi
        return 1
}

main()
{
	dir=$1
	page_server_port=$2
	server_msg_port=$3
	client_ip=$4
	client_msg_port=$5

	if [[ ! $dir =~ ^/[a-z]* ]]; then
                dir=$(get_full_path $dir)
        fi

	mkdir -p ${dir}
	mount -t tmpfs none ${dir}
	ret=$?
        print_log $ret $LINENO "mount tmpfs $dir"
        [ $ret -ne 0 ] && umount ${dir} && exit 1

	prev_images=""
	predump_cnt=$(receive $server_msg_port)
	for((i=0; i<${predump_cnt}; i++)); do
		mkdir -p ${dir}/${i}
		send $client_ip $client_msg_port ${i}
		# init page-server to receive pre-dump images
		criu page-server --images-dir ${dir}/${i} ${prev_images} --port $page_server_port --auto-dedup

		prev_images="--prev-images-dir ${dir}/${i}"
	done

	mkdir -p ${dir}/dump
	send $client_ip $client_msg_port "dump"

	# init page-server to receive dump images
	criu page-server --images-dir ${dir}/dump ${prev_images} --port $page_server_port --auto-dedup
	
	dump=$(receive $server_msg_port)
	if [ $dump == "finish" ]; then
		# restore process
		criu restore --images-dir ${dir}/dump --shell-job
		ret=$?
		print_log $ret $LINENO "criu restore ${dir}/dump"
		umount ${dir}
		[ $ret -ne 0 ] && exit 1
	fi
}

main $@
