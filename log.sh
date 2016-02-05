#!/bin/bash
log=${1}
export info=0
export error=1

fmt_log()
{
	ret=$1
	line=$2
	level=$3
	message=$4
	case $level in
		0)
			level="Info"
			LINE_NO=$line
			;;
		1)
			level="Error"
			LINE_NO=$line
			;;
	esac

	echo "$(date) $(pwd)/${0#[./]*/} line: ${LINE_NO} return value: $ret $level: $message" >> ${log}
}

print_log()
{
	ret=$1
	line=$2
	msg=$3
	if [ $ret -ne 0 ]; then
		fmt_log $ret $line $error "$msg failed!"
		return -1
	else
		fmt_log $ret $line $info "$msg success."
	fi
}

log_info()
{
	line=$1
	level=$2
	case $level in
		0)
			level="Info"
			;;
		1)
			level="Error"
			;;
	esac
	msg=$3
	echo "$(date) $(pwd)/${0#[./]*/} line: ${line} $level: $msg" >> ${log}
}

