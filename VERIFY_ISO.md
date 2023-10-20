### 2.3.270-20231006 ISO image built on 2023/10/06



### Download and Verify

2.3.270-20231006 ISO image:  
https://download.threatcode.net/file/threatcode/threatcode-2.3.270-20231006.iso

MD5: 3FC7A37EA402A5F0C6609D7431387575  
SHA1: 979851603E431EE9670A1576E5DCCD838CEDA294  
SHA256: 34F72EDEA9A62E1545347A31DEDEDD099D824466EC52B8674ACC7DB6D7E8B943 

Signature for ISO image:  
https://github.com/ThreatCode/threatcode/raw/master/sigs/threatcode-2.3.270-20231006.iso.sig

Signing key:  
https://raw.githubusercontent.com/ThreatCode/threatcode/master/KEYS  

For example, here are the steps you can use on most Linux distributions to download and verify our Threat Code ISO image.

Download and import the signing key:  
```
wget https://raw.githubusercontent.com/ThreatCode/threatcode/master/KEYS -O - | gpg --import -  
```

Download the signature file for the ISO:  
```
wget https://github.com/ThreatCode/threatcode/raw/master/sigs/threatcode-2.3.270-20231006.iso.sig
```

Download the ISO image:  
```
wget https://download.threatcode.net/file/threatcode/threatcode-2.3.270-20231006.iso
```

Verify the downloaded ISO image using the signature file:  
```
gpg --verify threatcode-2.3.270-20231006.iso.sig threatcode-2.3.270-20231006.iso
```

The output should show "Good signature" and the Primary key fingerprint should match what's shown below:
```
gpg: Signature made Thu 21 Sep 2023 10:43:13 AM EDT using RSA key ID FE507013
gpg: Good signature from "Threat Code Solutions, LLC <info@threatcodesolutions.com>"
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: C804 A93D 36BE 0C73 3EA1  9644 7C10 60B7 FE50 7013
```

Once you've verified the ISO image, you're ready to proceed to our Installation guide:  
https://docs.threatcode.net/en/2.3/installation.html
