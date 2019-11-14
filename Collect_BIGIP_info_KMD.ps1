#Initialize Snapin
if ( (Get-PSSnapin | Where-Object { $_.Name -eq "iControlSnapIn"}) -eq $null ){
    Add-PSSnapIn iControlSnapIn
}

#Add a type/class to store the BIG-IP info in
Add-Type @'
public class BIGIP_info
{
    public string host_name;
	public string platform;
	public string product_category;
	public string chassis_serial;
	public string Version;
	public string HF_version;
    public int UpTime;
    public string NtpServer;
    public string FailoverStatus;
}
'@


#-------------------------------------------------------------------------
#Function ConnectBIG-IP
#-------------------------------------------------------------------------
function funcConnectBIG-IP($LoginUser, $LoginPW, $BIGIP_HostName) {
#Connect to the BigIP and get an iControl Handle
	$Success = Initialize-F5.iControl -HostName $BIGIP_HostName -Username $LoginUser -Password $LoginPW
	if ($Success) {
#		write-host Succesfully connected to $BIGIP_HostName
#		$F5 = Get-F5.iControl
		return Get-F5.iControl
	} else {
#		write-host Connection to $BIGIP_HostName Failed!
		return $false
	}
}

#-------------------------------------------------------------------------
# function Decrypt-SecureString
#-------------------------------------------------------------------------
#https://blogs.msdn.microsoft.com/besidethepoint/2010/09/21/decrypt-secure-strings-in-powershell/    
function funcDecrypt-SecureString {
param(
    [Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=0)]
    [System.Security.SecureString]
    $sstr
)

$marshal = [System.Runtime.InteropServices.Marshal]
$ptr = $marshal::SecureStringToBSTR( $sstr )
$str = $marshal::PtrToStringBSTR( $ptr )
$marshal::ZeroFreeBSTR( $ptr )
$str
}


#-------------------------------------------------------------------------
# Main Application Logic
#-------------------------------------------------------------------------


#Setup credentials
Set-Location C:\Users\z5nev\Documents\PowerShell
$import_user_pw_secure = @(Import-Csv .\user_pw_secure.txt)
$User64 = $import_user_pw_secure.ID1
$User = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($User64))

$secure_password = $import_user_pw_secure.ID2 | ConvertTo-SecureString
$Password = funcDecrypt-SecureString $secure_password
#####

$BIGIP_List = Get-Content .\BigIpList_all.txt


$BIGIP_List
#Create an empty array to store the node objects in
$BIGIP_info = @()
	
#===============

#$BigIP_List = "oqcbigip.kmd.dk"

foreach ($BigIP in $BIGIP_List) {
	write-host ;
	write-host Connecting to $BigIP
	$F5 = funcConnectBIG-IP $User $Password $BigIP
	if (-not ($F5)) {
	write-host Connection to $BigIP Failed! 
	} else {
		write-host Succesfully connected to $BigIP
		
		$objTempBigIp = New-Object BIGIP_info
		$objTempBigIp.host_name = ($F5.SystemSystemInfo.get_system_information()).host_name
		$objTempBigIp.platform = ($F5.SystemSystemInfo.get_system_information()).platform
		$objTempBigIp.product_category = ($F5.SystemSystemInfo.get_system_information()).product_category
		$objTempBigIp.chassis_serial = ($F5.SystemSystemInfo.get_system_information()).chassis_serial
		$objTempBigIp.Version = $F5.SystemSystemInfo.get_version()
		$objTempBigIp.HF_version = ($F5.SystemSystemInfo.get_product_information()).package_edition
        $objTempBigIp.UpTime = [System.Math]::Round($F5.SystemSystemInfo.get_uptime()/60/60/24)
        $objTempBigIp.NtpServer = $f5.SystemInet.get_ntp_server_address()

        $BigipGetVersion = $F5.SystemSystemInfo.get_version()
        if ($BigipGetVersion -like '*10*') {
   		} else {
		    $objTempBigIp.FailoverStatus = ($f5.ManagementDeviceGroup.get_failover_status()).status
	    }

	
		$BIGIP_info += $objTempBigIp
		write-host ;
#		$BIGIP_info
	}
}

#===============
$BIGIP_info | Out-GridView
$BIGIP_info | Out-File .\BIGIP_info_KMD_out.txt

#$Nodes = @()
