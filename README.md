# recon-script
Bash script for recon work

## Usage 
```
chmod +x recon.sh
./recon.sh --input domains.txt --output results
```

## Example targets file(domain.txt)
```
example.com
testsite.org
corpdomain.net
```
## Result Tree
```
results/
└── example.com/
    ├── subfinder.txt
    ├── assetfinder.txt
    ├── subdomains.txt
    ├── resolved.txt
    ├── httpx.json         <-- HTTP metadata
    ├── alive.txt          <-- Aktive services URL's
    ├── nmap_<ip>.xml      <-- Nmap port scan results
results/summary.txt       <-- Summary
```
