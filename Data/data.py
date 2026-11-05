import re
from unidecode import unidecode

nicknameArray = [
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26298SK.OO.D101CR.01",
        "Nickname": "57th Street"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "25995IP",
        "Nickname": "Alinghi"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26062FS.OO.A002CA.01",
        "Nickname": "Alinghi"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26062OR.OO.A002CA.01",
        "Nickname": "Alinghi"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26062PT.OO.A002CA.01",
        "Nickname": "Alinghi"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26076SK",
        "Nickname": "Alinghi"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "67610ST",
        "Nickname": "Alinghi"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "67611ST",
        "Nickname": "Alinghi"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": None,
        "Reference": None,
        "Nickname": "AP"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "25770SN",
        "Nickname": "Arnold Schwarzenegger End of Days"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26420CE",
        "Nickname": "Arnold Schwarzenegger End of Days"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "263781O.OO.A001KE.01",
        "Nickname": "Arnold Schwarzenegger The Legacy"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "25863TI.00.A001CU.01",
        "Nickname": "Arnold Schwarzenegger The T3"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "25863TI.00.A080CU.01",
        "Nickname": "Arnold Schwarzenegger The T3"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": None,
        "Reference": None,
        "Nickname": "Audemars"
    },
    {
        "Brand": "Rolex",
        "Model": "GMT Master",
        "Reference": "6542",
        "Nickname": "Bakelite"
    },
    {
        "Brand": "Rolex",
        "Model": "Chronografo",
        "Reference": "3525",
        "Nickname": "Barilotto"
    },
    {
        "Brand": "Rolex",
        "Model": "GMT Master II",
        "Reference": "116710BLNR",
        "Nickname": "Batman"
    },
    {
        "Brand": "Rolex",
        "Model": "GMT Master II",
        "Reference": "126710BLNR",
        "Nickname": "Batman"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "25721BA",
        "Nickname": "Beast"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "25721ST",
        "Nickname": "Beast"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak",
        "Reference": "26620IO.OO.D077CA.01",
        "Nickname": "Black Panther"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26020ST.OO.D001IN.01",
        "Nickname": "Black Themes"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26170ST.OO.1000ST.08",
        "Nickname": "Black Themes"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26170ST.OO.D101CR.03",
        "Nickname": "Black Themes"
    },
    {
        "Brand": "Rolex",
        "Model": "Submariner",
        "Reference": "116613LB",
        "Nickname": "Bluesy"
    },
    {
        "Brand": "Rolex",
        "Model": "Submariner",
        "Reference": "126613LB",
        "Nickname": "Bluesy"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26470OR.OO.1000OR",
        "Nickname": "Brick"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26176FO",
        "Nickname": "Bumblebee"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26408OR.OO.A010CA.01",
        "Nickname": "Byblos"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26400SO.OO.A054CA.01",
        "Nickname": "Combat or Camo"
    },
    {
        "Brand": "Rolex",
        "Model": "Submariner",
        "Reference": "126619LB",
        "Nickname": "Cookie Monster"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26470SO.OO.A002CA.01",
        "Nickname": "Dark Knight"
    },

    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26470ST.OO.A104CR.01",
        "Nickname": "Elephant"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 69",
        "Reference": None,
        "Nickname": "Erotic Tourbillon"
    },
    {
        "Brand": "Rolex",
        "Model": "Daytona",
        "Reference": "116598TBR",
        "Nickname": "Eye of the tiger"
    },
    {
        "Brand": "Rolex",
        "Model": "GMT Master II",
        "Reference": "16760",
        "Nickname": "Fat Lady"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 011-FM",
        "Reference": None,
        "Nickname": "Felipe Massa"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 056",
        "Reference": None,
        "Nickname": "Felipe Massa"
    },
    {
        "Brand": "F.P. Journe",
        "Model": None,
        "Reference": None,
        "Nickname": "FPJ"
    },
    {
        "Brand": "Rolex",
        "Model": "Explorer II",
        "Reference": "1655",
        "Nickname": "Freccione"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26470IO.OO.A006CA.01",
        "Nickname": "Ghost"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26290IO.OO.A001VE.01",
        "Nickname": "Grand Prix"
    },
    {
        "Brand": "H. Moser & Cie.",
        "Model": None,
        "Reference": None,
        "Nickname": "H. Moser"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26470ST.OO.A820CR.01",
        "Nickname": "Havana"
    },
    {
        "Brand": "Rolex",
        "Model": "Submariner",
        "Reference": "116610LV",
        "Nickname": "Hulk"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26470ST.OO.A030CA.01",
        "Nickname": "Indigo"
    },
    {
        "Brand": "Jaeger-LeCoultre",
        "Model": None,
        "Reference": None,
        "Nickname": "Jaeger"
    },
    {
        "Brand": "Rolex",
        "Model": "Submariner",
        "Reference": "6538",
        "Nickname": "James Bond"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26055OR.OO.D001CR.01",
        "Nickname": "Jay-Z"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26055PT.OO.D001CR.01",
        "Nickname": "Jay-Z"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26055ST.OO.D001CR.01",
        "Nickname": "Jay-Z"
    },
    {
        "Brand": "Rolex",
        "Model": "Oyster Chronograph",
        "Reference": "4767",
        "Nickname": "Jean Claude Killy"
    },
    {
        "Brand": "Rolex",
        "Model": "Oyster Chronograph",
        "Reference": "6236",
        "Nickname": "Jean Claude Killy"
    },
    {
        "Brand": "Rolex",
        "Model": "Oyster Chronograph",
        "Reference": "5036",
        "Nickname": "Jean Claude Killy"
    },
    {
        "Brand": "Rolex",
        "Model": "Oyster Chronograph",
        "Reference": "6036",
        "Nickname": "Jean Claude Killy"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 036",
        "Reference": None,
        "Nickname": "Jean Todt"
    },
    {
        "Brand": "F.P. Journe",
        "Model": None,
        "Reference": None,
        "Nickname": "Journe"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26030",
        "Nickname": "Juan Pablo Montoya"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "5402",
        "Nickname": "Jumbo"
    },
    {
        "Brand": "Rolex",
        "Model": "Submariner",
        "Reference": "16610LV",
        "Nickname": "Kermit"
    },

    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26201SN.OO.D101CR.01",
        "Nickname": "Lava"
    },
    {
        "Brand": "Jaeger-LeCoultre",
        "Model": None,
        "Reference": None,
        "Nickname": "Le-Coultre"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26210OI.OO.A109CR.01",
        "Nickname": "Lebron James"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26325PL.OO.D310CR.01",
        "Nickname": "Leo Messi"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26325OL.OO.D005CR.01",
        "Nickname": "Leo Messi"
    },
    {
        "Brand": "Rolex",
        "Model": "Daytona",
        "Reference": "116598SACO",
        "Nickname": "Leopard"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 50-3",
        "Reference": None,
        "Nickname": "McLaren"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 11-03",
        "Reference": None,
        "Nickname": "McLaren"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26568IM.OO.A004CA.01",
        "Nickname": "Michael Schumacher"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26568OM.OO.A004CA.01",
        "Nickname": "Michael Schumacher"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26568PM.OO.A021CA.01",
        "Nickname": "Michael Schumacher"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 051",
        "Reference": None,
        "Nickname": "Michelle Yeoh"
    },
    {
        "Brand": "Rolex",
        "Model": "Submariner",
        "Reference": "5517",
        "Nickname": "Militare"
    },
    {
        "Brand": "H. Moser & Cie.",
        "Model": None,
        "Reference": None,
        "Nickname": "Moser"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 035-02",
        "Reference": None,
        "Nickname": "Nadal"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 035-03",
        "Reference": None,
        "Nickname": "Nadal"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 027",
        "Reference": None,
        "Nickname": "Nadal"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 035-01",
        "Reference": None,
        "Nickname": "Nadal"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26279IK.GG.D002CA.01",
        "Nickname": "National Classic Tour 2009"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26170ST.OO.D305CR.01",
        "Nickname": "Navy"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26020ST.OO.D020IN.01",
        "Nickname": "Navy"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26082TK.OO.D002CA.01",
        "Nickname": "Orchard Road"
    },
    {
        "Brand": "Rolex",
        "Model": "Oyster",
        "Reference": "3130",
        "Nickname": "Ovetto"
    },
    {
        "Brand": "Rolex",
        "Model": "Datejust",
        "Reference": "6105",
        "Nickname": "Ovettone"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 53-1",
        "Reference": None,
        "Nickname": "Pablo Mac Donough"
    },
    {
        "Brand": "Rolex",
        "Model": "Padellone",
        "Reference": "8171",
        "Nickname": "Padellone"
    },
    # Removed: "Parmegiani" nickname - was a typo, "Parmigiani" matches brand "Parmigiani Fleurier" directly
    {
        "Brand": "Patek Philippe",
        "Model": None,
        "Reference": None,
        "Nickname": "Patek"
    },
    {
        "Brand": "Rolex",
        "Model": "GMT Master II",
        "Reference": "126710BLRO",
        "Nickname": "Pepsi"
    },
    {
        "Brand": "Patek Philippe",
        "Model": None,
        "Reference": None,
        "Nickname": "PP"
    },
    {
        "Brand": "Rolex",
        "Model": "Pre Daytona",
        "Reference": "6238",
        "Nickname": "Pre Daytona"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26365IS.OO.D305CR.01",
        "Nickname": "Pride of Argentina"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26365OR.OO.D801CR.01",
        "Nickname": "Pride of Argentina"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26168SR.OO.1220SR.01",
        "Nickname": "Pride of China"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26168SR.OO.1220SR.02",
        "Nickname": "Pride of China"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26415CE.OO.A002CA.01",
        "Nickname": "Pride of Germany"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26416RO.OO.A002CA.01",
        "Nickname": "Pride of Germany"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26179IR.OO.A005CR.01",
        "Nickname": "Pride of Indonesia"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26326ST.OO.D027CA.01",
        "Nickname": "Pride of Italy"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26297IS.OO.D101CR.01",
        "Nickname": "Pride of Mexico"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26297OR.OO.D101CR.01",
        "Nickname": "Pride of Mexico"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26061BC.OO.D028CR.01",
        "Nickname": "Pride of Russia"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26061OR.OO.D002CR.01",
        "Nickname": "Pride of Russia"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26172SO.OO.D202CR.01",
        "Nickname": "Pride of Siam"
    },
    {
        "Brand": "Rolex",
        "Model": "Daytona",
        "Reference": "116598RBOW",
        "Nickname": "Rainbow"
    },
    {
        "Brand": "Richard Mille",
        "Model": None,
        "Reference": None,
        "Nickname": "RM"
    },
    {
        "Brand": "Rolex",
        "Model": "GMT Master II",
        "Reference": "126711CHNR",
        "Nickname": "Root Beer or Rootbeer"
    },
    {
        "Brand": "Rolex",
        "Model": "GMT Master II",
        "Reference": "126715CHNR",
        "Nickname": "Root Beer or Rootbeer"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "25940",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26071",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26082",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26238",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26262",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26278",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26279",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26296",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26298",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26377",
        "Nickname": "Rubberclad"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26020ST.OO.D091CR.01",
        "Nickname": "Safari"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26170ST.OO.D091CR.01",
        "Nickname": "Safari"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26207IO.OO.A002CA.01",
        "Nickname": "Sebastien Buemi"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26133ST.OO.A101CR.01",
        "Nickname": "Shaquille O’Neal"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26134BC.ZZ.A101CR.01",
        "Nickname": "Shaquille O’Neal"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 052",
        "Reference": None,
        "Nickname": "Skull"
    },
    {
        "Brand": "Rolex",
        "Model": "Submariner",
        "Reference": "116619LB",
        "Nickname": "Smurf"
    },
    {
        "Brand": "Rolex",
        "Model": "GMT Master II",
        "Reference": "126720VTNR",
        "Nickname": "Sprite"
    },
    {
        "Brand": "Rolex",
        "Model": "Submariner",
        "Reference": "126610LV",
        "Nickname": "Starbucks"
    },
    {
        "Brand": "Rolex",
        "Model": "Calendario",
        "Reference": "6062",
        "Nickname": "Stelline"
    },
    {
        "Brand": "Rolex",
        "Model": "Explorer II",
        "Reference": "1655",
        "Nickname": "Steve Mc. Queen"
    },
    {
        "Brand": "Rolex",
        "Model": "Solo tempo quarzo",
        "Reference": "5100",
        "Nickname": "Texano"
    },
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26278IK.GG.D002CA.01",
        "Nickname": "Tour Auto 2009"
    },

    {
        "Brand": "Ulysse Nardin",
        "Model": None,
        "Reference": None,
        "Nickname": "UN"
    },

    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26470ST.OO.A101CR.01",
        "Nickname": "Vampire"
    },
   
    {
        "Brand": "Audemars Piguet",
        "Model": "Royal Oak Offshore",
        "Reference": "26170ST.OO.D101CR.01",
        "Nickname": "Volcano"
    },
    {
        "Brand": "Richard Mille",
        "Model": "RM 59-1",
        "Reference": None,
        "Nickname": "Yohan Blake"
    },
    {
        "Brand": "Rolex",
        "Model": "Daytona",
        "Reference": "16520",
        "Nickname": "Zenith"
    },
    {
        "Nickname": "Great White",
        "Brand": None,
        "Model": None,
        "Reference": None
    },
    {
        "Nickname": "Big Red",
        "Brand": None,
        "Model": None,
        "Reference": None
    },
    {
        "Nickname": "Double Red",
        "Brand": None,
        "Model": None,
        "Reference": None
    },
    {
        "Nickname": "JLC",
        "Brand": "Jaeger-LeCoultre",
        "Model": None,
        "Reference": None
    },
    {
        "Nickname": "Explorer I",
        "Brand": None,
        "Model": "Explorer",
        "Reference": None,
        "IsNickname": False
    },
    {
        "Nickname": "Explorer 1",
        "Brand": None,
        "Model": "Explorer",
        "Reference": None,
        "IsNickname": False
    },
    {
        "Nickname": "Explorer 2",
        "Brand": None,
        "Model": "Explorer II",
        "Reference": None,
        "IsNickname": False
    },
    {
        "Nickname": "VC",
        "Brand": "Vacheron Constantin",
        "Model": None,
        "Reference": None
    },
    {
        "Nickname": "Vacheron",
        "Brand": "Vacheron Constantin",
        "Model": None,
        "Reference": None
    }
]

# Group nicknameArray by Nickname


def groupby(iterable, key=lambda x: x):
    groups = {}
    for item in iterable:
        groups.setdefault(key(item), []).append(item)
    return groups.items()

def cleanText(text):
    text = ''.join(e for e in text if e.isalnum() or e == " ")
    text = re.sub(' +', ' ', text)
    text = unidecode(text.strip())
    text = text.replace("-", " ").lower()
    return text

groupedNicknameArray = {k: list(v) for k, v in groupby(
    nicknameArray, key=lambda x: cleanText(x['Nickname']))}

nicknameMap = groupedNicknameArray

nicknameMapKeys = [nicknameMap[k][0]["Nickname"] for k in nicknameMap.keys()]
