# !/bin/bash
#
#-f robot
#
function Usage {
    #使用方法
    echo "Usage: $0 [args][values]"
    echo "    -H [filename]  host's IP,Port,user,password list"
    echo "    -f [filename]  ecpect script file"
    echo "    -t [num]  set thread numbers"
    echo "    -h print this message"
}

# #----解析参数
if [ $# -lt 2 ]; then
    echo "Not enough argument"
    Usage
    exit 0
fi

thread=10 #此处定义线程数

while getopts "t:H:f:" arg #选项后面的冒号表示该选项需要参数
do
    case $arg in
        t) # 线程数参数
                expr $OPTARG "+" 10 &> /dev/null
                if [ $? -eq 0 ] && [ $OPTARG -gt 0 ]; then
                    echo "Thread number is $OPTARG."
                    thread=$OPTARG
                else
                    echo "$OPTARG is not number."
                    exit 1
                fi
        ;;
        H) # 主机文件列表
           # 主机格式： ID	IP	Port	Passwd
            if [ -f $OPTARG ]; then
                echo "Use file $OPTARG."
                hostsFile=$OPTARG
            else
                echo "file $OPTARG can not find."
                exit 1
            fi
        ;;
        f) # 执行脚本文件
            if [ -f $OPTARG ]; then
                echo "Use file $OPTARG."
                expFile=$OPTARG
            else
                echo "file $OPTARG can not find."
                exit 1
            fi
        ;;
        h)
            Usage
            exit 0
        ;;
        ?)  #未知参数
            echo "Unknow argument"
			Usage
            exit 1
        ;;
    esac
done
#-------

function Install { # 此处定义一个函数，作为一个线程(子进程)
#IP Port Passwd ID
    expect $expFile $2 $3 $4 $1
    return 0
}

LogFile=`date +%Y%m%d-%H%M`.log

#-----设置线程数 start
tmp_fifofile="/tmp/$$.fifo"
mkfifo ${tmp_fifofile}      # 新建一个fifo类型的文件
exec 6<>${tmp_fifofile}      # 将fd6指向fifo类型
rm ${tmp_fifofile}

for ((i=0;i<$thread;i++));
do
    echo
done >&6 # 事实上就是在fd6中放置了$thread个回车符

echo `date '+%Y/%m/%d %H:%m:%S'` "Start install from host [$hostsFile]"|tee -a $LogFile

while read hostID hostIP hostPort hostPasswd ;
do # 50次循环，可以理解为50个主机，或其他
read -u6
  # 一个read -u6命令执行一次，就从fd6中减去一个回车符，然后向下执行，
  # fd6中没有回车符的时候，就停在这了，从而实现了线程数量控制
{ # 此处子进程开始执行，被放到后台
    Install $hostID $hostIP $hostPort $hostPasswd && { # 此处可以用来判断子进程的逻辑
            echo `date '+%Y/%m/%d %H:%m:%S'` "Install $hostID $hostIP $hostPort $hostPasswd OK"|tee -a $LogFile
        } || {
            echo `date '+%Y/%m/%d %H:%m:%S'` "Install $hostID $hostIP $hostPort $hostPasswd Failed"|tee -a $LogFile
        }
        echo >&6 # 当进程结束以后，再向fd6中加上一个回车符，即补上了read -u6减去的那个
} &
done < $hostsFile

wait # 等待所有的后台子进程结束
exec 6>&- # 关闭df6
exit 0
