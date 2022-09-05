# Ubuntu root file system on ZFS

參考資料: [Ubuntu 20.04 Root on ZFS](https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2020.04%20Root%20on%20ZFS.html)
<br>
使用方式:

    1. 使用 Ubuntu desktop 20.04 安裝碟 開機.
    2. 開啟 Terminal
    3. 切換到root 權限, 並設定root 密碼  
    4. 安裝 openssh-server, 以方便將下列script 拷貝到系統中.
    5. 將 Ubuntu_Root_On_ZFS.sh 以及 Run_it_after_first_boot.sh 拷貝到/root 目錄下.
    6. 先修改 Ubuntu_Root_On_ZFS.sh 及 Run_it_after_first_boot.sh 設定
    7. 執行 Ubuntu_Root_On_ZFS.sh
    8. 執行完後, 重新開機. (有可能會無法匯入 zpool, 請手動(或強制) 匯入 bpool, rpool, 然後再重新開機)
    9. 第一次開機成功後, 執行 Run_it_after_first_boot.sh 以完成最後系統安裝. 完成後, 重開機即可


 