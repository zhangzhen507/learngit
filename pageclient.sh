#!/bin/bash

source log.sh /var/log/pageclient.log

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
	binary=$1
	dir=$2
	client_msg_port=$3
	svr_ip=$4
	page_server_port=$5
	server_msg_port=$6
	predump_cnt=$7


	# get binary pid
	pid=$(ps -C $binary | grep $binary | awk '{print $1}')
	ret=$?
	print_log $ret $LINENO "get pid=$pid from ps -C $binary"
	[ $ret -ne 0 ] && exit 1

	# get binary absoluate path
	binary_dir=$(cat /proc/$pid/cmdline)
	log_info $LINENO $info "binary = $binary binary_dir=$binary_dir"

	if [[ ! $dir =~ ^/[a-z]* ]]; then
                dir=$(get_full_path $dir)
        fi
	log_info $LINENO $info "dir = $dir"

 	echo 4 >> /proc/$pid/clear_refs
	
	# mount images dir
	mkdir -p ${dir}
	mount -t tmpfs none ${dir}
	ret=$?
	print_log $ret $LINENO "mount tmpfs $dir"
	[ $ret -ne 0 ] && umount ${dir} && exit 1
	
	prev_images=""
	# send pre_dump count
	send $svr_ip $server_msg_port $predump_cnt
	
	while true; do
		# receive current pre-dump number
		idx=$(receive $client_msg_port)
		if [[ ${idx} == "dump" ]]; then
			break;
		fi

		mkdir -p ${dir}/${idx}
		
		# pre-dump
		while true; do
			criu pre-dump -t $pid --images-dir ${dir}/${idx} ${prev_images} --track-mem --page-server --address ${svr_ip} --port ${page_server_port}
			[ $? -eq 0 ] && break
		done
		prev_images="--prev-images-dir ${dir}/${idx}"
	done

	mkdir -p ${dir}/dump
	# dump
	while true; do
		criu dump -t $pid --images-dir ${dir}/dump ${prev_images} --track-mem --page-server --address ${svr_ip} --port ${page_server_port} --shell-job
		[ $? -eq 0 ] && break
	done

	# copy dump images to target host
	scp -r ${dir}/dump/* root@${svr_ip}:${dir}/dump/
	ret=$?
	print_log $ret $LINENO "copy ${dir}/dump/* to $svr_ip ${dir}/dump"
	[ $ret -ne 0 ] && umount ${dir} && exit 1

	predir=$(dirname $binary_dir)
	ssh $svr_ip "mkdir -p $predir"
	scp $binary_dir root@${svr_ip}:$predir
	ret=$?
	print_log $ret $LINENO "copy $binary_dir to $svr_ip $binary_dir"
	[ $ret -ne 0 ] && umount ${dir} && exit 1

	# send dump finish
	send $svr_ip $server_msg_port "finish"

	# umount imgages directory
	umount ${dir}
}

main $@
