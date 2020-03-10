#!/usr/bin/env bash

expiredPeriod=`expr 60 \* 60 \* 24 \* 7`
backPath="/root/backup"

onlineCluster="https://10.10.3.62:2379"
backupPeriod=`expr 60 \* 30`
isTodayBackup=false
previousBuckupDay=0
backupClockRand=1

function rand(){   
    min=$1   
    max=$(($2-$min+1))   
    num=$(cat /proc/sys/kernel/random/uuid | cksum | awk -F ' ' '{print $1}')   
    echo $(($num%$max+$min))   
}   

backupClockRand=$(rand 1 5)  

createBackupDirectory() {
    if [ ! -d "$backPath" ]; then
        mkdir $backPath
    else
        echo "[info] $backPath exist, nothing to do"
    fi
}

createBackupFile()
{
    curDateTime=`date +%Y-%m-%d@%H:%M:%S`
    curUnixTime=`date +%s`
    buckupFileName="$curUnixTime=$curDateTime.db"

    ETCDCTL_API=3 etcdctl --cacert=/root/tls/ca.pem --cert=/root/tls/etcd.pem --key=/root/tls/etcd-key.pem --endpoints=$1 snapshot save $2"/"$buckupFileName
}

deleteExpiredFile()
{
    for file in `ls $1`
    do
        if [ -d $file ]; then
            echo "is a path"
        else
            suffix=${file#*.}
            
            if [ "$suffix" = "db" ]; then  
                array=(`echo $file | tr '=' ' '` )
                fileTimestramp=${array[0]}

                nowUnixTime=`date +%s`
                expiredTime=`expr $nowUnixTime - $2`

                if [ $fileTimestramp -lt $expiredTime ]; then
                    echo "less: $file - $fileTimestramp < $expiredTime"
                    rm $1"/"$file
                fi
            fi
        fi
    done
}

runBackupAtAppointTime()
{
    curDateDay=`date +%j`
    curTime=`date +%T`
    
    if [ $previousBuckupDay -eq $curDateDay ]; then 
        clockArray=(`echo $curTime | tr ':' ' '` )
        curClock=${clockArray[0]}
        if [[ $((10#$curClock)) -eq $backupClockRand ]]; then
            if [ "$isTodayBackup" = true ]; then
                echo "[info] The backup operation has been performed today."
            else
                echo "[info] begin run backup at $curTime"
                createBackupFile $onlineCluster $backPath
                deleteExpiredFile $backPath $expiredPeriod
                isTodayBackup=true
            fi
        fi
    else
        backupClockRand=$(rand 1 5)  
        isTodayBackup=false
        previousBuckupDay=$curDateDay
    fi
}

backupProcess()
{
    createBackupDirectory

    while true
    do
        runBackupAtAppointTime

        sleep $backupPeriod
    done
}
backupProcess

#nohup /root/backup.sh > /root/backup/backup.log 2>&1 &














