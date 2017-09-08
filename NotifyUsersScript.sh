#!/bin/sh                                                                                                                                                                                                                                                                                
# Todd Houle                                                                                                                                                                                                                                                                             
# 8Sept2017                                                                                                                                                                                                                                                                              
# Notify users if over quota in Crashplan                                                                                                                                                                                                                                                


sendMail(){

BODY="<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">                                                                                                                                                                         
<html>                                                                                                                                                                                                                                                                                   
<head><title>Code42 Crashplan Quota Notice</title>                                                                                                                                                                                                                                       
</head>                                                                                                                                                                                                                                                                                  
<body>                                                                                                                                                                                                                                                                                   
                                                                                                                                                                                                                                                                                         
Your backup account is currently over quota using $3GB of your $2GB quota. Backups will not run until the storage requirement is reduced.  In order for the backup service to be available to all users we must limit storage.  Please use one of the following strategies to reduce you\
r storage requirement. <P>                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                                                         
<ul>                                                                                                                                                                                                                                                                                     
<li>Remove a computer from being backed up, if you have multiple computers.  Be sure to contact the Service Desk to remove the computer from the server as well as the application from the machine.                                                                                     
<li>Select less data to backup.  Perhaps deselect Downloads or Desktop folders -  or folders containing large amounts of data that do not need to be backed up.                                                                                                                          
<li>Set an exclusion filetype.  In the Crashplan application, click 'Details' on a computer, then click the Gear icon.  Enter a File Exclusion, such as JPG, to not backup up jpeg images.                                                                                               
<li><a href=https://servicedeskform/>Submit a Service Desk Ticket</a>                                                                                                                                                            
</ul>                                                                                                                                                                                                                                                                                    
Once settings are changed, backups will resume within an hour.                                                                                                                                                                                                                           
</body>                                                                                                                                                                                                                                                                                  
</html>"

SUBJECT="Code42 Backup Over Quota"
FROM='noreply@company.com'
TO=$1
                                                                                                                                                                                                                                                            

#echo "send to $TO here, quota $2 used $3"                                                                                                                                                                                                                                               
printf "From: <%s>\nTo: <%s>\nSubject: %s\nMIME-Version: 1.0\nContent-Type: text/html\n\n%s" "$FROM" "$TO" "$SUBJECT" "$BODY" | sendmail -f "$FROM" -t "$TO"

}



##################                                                                                                                                                                                                                                                                       

curl -s -S -H 'Content-Type: application/json' -X GET -u 'adminuser:Sekret' 'https://CPserver:4285/api/User?pgSize=9999&active=true'|python -m json.tool|grep username|grep -v usernameIsAnEmail|awk -F\" '{print $4}'|sort -u > /tmp/crashplanUsers.txt

while read line; do
    if [ ! $line == " " ]; then
        totalSpaceUsed=0

        #get quota for user                                                                                                                                                                                                                                                              
        quotaForUser=$(curl -s -S -H 'Content-Type: application/json' -X GET -u 'adminuser:Sekret' "https://CPserver:4285/api/User?q=$line&active=true"|python -m json.tool|grep "quotaInBytes"|awk -F: '{print $2}'|tr -d , )

        #List computers by a user                                                                                                                                                                                                                                                        
        spacePerDevice=$(curl -s -S -H 'Content-Type: application/json' -X GET -u 'adminuser:Sekret' "https://CPserver:4285/api/DeviceBackupReport?user=$line&active=true"|python -m json.tool|grep archiveBytes |awk -F\" '{print $4}')
        spacePerDeviceArr=($spacePerDevice)  #convert to array                                                                                                                                                                                                                           
        IFS=+ read <<< "${spacePerDeviceArr[*]}"
        ((sum=REPLY))

        if [ "$sum" -ge "$quotaForUser" ] && [ "$quotaForUser" -ne "0" ] && [ "$quotaForUser" -ne "-1" ]; then
            echo "user $line is t need to be backed up.over quota: used: $sum  quota: $quotaForUser"
            userEmail=$(curl -s -S -H 'Content-Type: application/json' -X GET -u 'adminuser:Sekret' "https://CPserver:4285/api/User?q=$line&active=true"|python -m json.tool |grep email|grep -v emailPromo |awk -F\" '{print $4}')
            quotaGB=$(echo "$quotaForUser / 1000000000" |bc)
            sumGB=$(echo "$sum / 1000000000" |bc)
            sendMail $userEmail $quotaGB $sumGB
        fi

    fi
done </tmp/crashplanUsers.txt

echo $(date) >> /tmp/crashplanUsers.txt
mv /tmp/crashplanUsers.txt /tmp/crashplanUsers.$$.txt
