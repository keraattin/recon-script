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
    ├── httpx.json           <-- HTTP metadata
    ├── alive.txt            <-- Aktive services URL's
    ├── nmap_<ip>.xml        <-- Nmap port scan results
    ├── fuzzing_results.txt  <-- Gobuster fuzzing results
results/summary.txt       <-- Summary
```

## Required Programs
```
- subfinder
- assetfinder
- dnsx
- httpx
- nmap
- gobuster
- gospider
```
