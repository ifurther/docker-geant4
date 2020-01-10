import threading
import requests
from pathlib import Path
from argparse import ArgumentParser


parser = ArgumentParser()
parser.add_argument("pos1", help="Geant4DatasetDefinitions.cmake file", default="cmake/Modules/Geant4DatasetDefinitions.cmake")
parser.add_argument("-o", "--output-dir", help="output dir", dest="opd", default="./data")
args = parser.parse_args()

Geant4Dataset={}

downloaddir=Path(args.opd)
if not downloaddir.exists():
    downloaddir.mkdir()

def download(link, filelocation):
    #r = requests.get(link, stream=True)
    with requests.get(link, stream=True) as r:
        if r.status_code == 200 :
            with open(filelocation, 'wb') as f:
                f.write(r.raw.read())
        else:
            print('network error')

def createNewDownloadThread(link, filelocation):
    download_thread = threading.Thread(target=download, args=(link,filelocation))
    download_thread.start()

if Path(args.pos1).exists():
    cmakedatafile = Path(args.pos1)
else:
    print('{} is not found.'.format(args.pos1)) 

with open(cmakedatafile,'r',newline='') as cs:
        t=cs.readlines()
        for i in range(len(t)):
            if 'geant4_add_dataset' in t[i]:
                Name=t[i+1].split('   ')[2].replace('\n','')
                Version=t[i+2].split(' ')[5].replace('\n','')
                filename=t[i+3].split('  ')[2].replace('\n','')
                Ext=t[i+4].split(' ')[3].replace('\n','')
                print("Name is {}, version {}".format(Name,Version),
                "filename is {}.{}".format(filename,Ext)
                )
                Geant4Dataset[Name]=filename+'.'+Version+'.'+Ext
               
for Name in Geant4Dataset:
    file = downloaddir.joinpath(Geant4Dataset[Name])
    print("{}".format(file))
    if not file.exists():
        createNewDownloadThread("http://geant4-data.web.cern.ch/geant4-data/datasets/"+Geant4Dataset[Name], file)

with open ('downdata.sh', 'w') as rsh:
    rsh.write('''\
        #! /bin/bash
        echo "starting download"
        ''')
    rsh.write('''\
        geant4_data_path=$(pwd)/data
        if [ -e $geant4_data_path ];then
           mkdir -p $geant4_data_path
        fi
        ''')
    rsh.write('data_url="http://geant4-data.web.cern.ch/geant4-data/datasets/"')
    rsh.write('geant4_data=[')
    for ii in [str(v) for k, v in Geant4Dataset.items()]:
        rsh.write(ii+' ')
    rsh.write(']')
    rsh.write('''\
        cd $geant4_data_path
        for data in geant4_data;do
           wget $data_url$ii;
           tar xf $ii;
           rm -rf $ii;
        done
        echo "finish"
        ''' )