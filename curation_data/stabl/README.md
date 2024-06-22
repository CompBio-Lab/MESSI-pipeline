# STABL

Data retrived from their `Sample Data`, under a `data.zip` file.

Run this command under the directory of this README file to pull the data zip

> Note this requires internet

```bash
wget -O data.zip https://github.com/gregbellan/Stabl/raw/main/Sample%20Data/data.zip
```

Once downloaded, then you could unzip it

```bash
unzip data.zip -d stabl_data
```

Then, only retaining those datasets with classification problem
```bash
# Careful with these commands
cd stabl_data
rm -r CFRNA/
rm -r COVID-19
rm -r Onset\ of\ Labor
# Do a rename for biobank SSI
mv Biobank\ SSI/ biobank_ssi  
```