#!/bin/bash
CURR_DIR=$(pwd)

# 判斷參數數量是否為1或2
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "用法錯誤！正確語法：$0 IP_Address [Interval]"
  exit 1
fi

# 判斷第一個參數是否為有效的IP地址
if ! [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "用法錯誤！你必須輸入一個有效的IP地址"
  exit 1
fi

# 判斷第二個參數是否為整數，如果有提供的話
if [ -n "$2" ] && ! [[ $2 =~ ^[0-9]+$ ]]; then
  echo "用法錯誤！第二個參數必須是一個正整數，代表ping的間隔秒數"
  exit 1
fi

# 設定IP和間隔
IP=$1
INTERVAL=${2:-1} # 如果未提供第二個參數，則設定為1秒

# 建立log目錄（如果還不存在的話）
LOG_DIR=${CURR_DIR}/ping_log
mkdir -p ${LOG_DIR}

# 建立log檔案名稱
LOG_FILE="${LOG_DIR}/ping_${IP}_$(date +%Y%m%d_%H%M%S).log"

# 檢查是否已有相同的log檔案，如果有的話，就改名備份
if [ -f $LOG_FILE ]; then
  mv $LOG_FILE "${LOG_FILE}_bak"
fi

# 無限ping，並將輸出寫入log檔案
ping -i ${INTERVAL} ${IP} | while read pong; do echo "$(date +%Y-%m-%d\ %H:%M:%S): $pong"; done | tee ${LOG_FILE}



