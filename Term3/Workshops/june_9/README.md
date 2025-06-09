# Berserk MongoDB 

This repository contains everything you need to explore and experiment with MongoDB query operators—using **real “Berserk” anime data**. We’ve built two collections:

1. **`characters`**  
   Stores four sample Berserk characters (Guts, Griffith, Casca, Farnese).  
2. **`operator_docs`**  
   A “lookup” collection where each document encapsulates:
   - An operator name (e.g. `$eq`, `$gte`, `$regex`, etc.)  
   - A one-line **purpose/description**  
   - The exact **syntax** you’d copy-paste into `mongosh`  
   - The **example output** you should see  

Whenever a user wants to learn how a particular operator works on _our_ Berserk data, they simply run:
```js
db.operator_docs.find({ operator: "<OPERATOR_NAME>" })

## Cloning and Importing JSON Data

If you’ve cloned this repo, you already have:
- `berserk_characters.json`
- `berserk.operator_docs.json`
- `README.md`

To import these into your local MongoDB:

1. Open a terminal in this folder (e.g., `Term3/Workshops/june_9`).

2. Run:
   ```bash
   mongoimport \
     --db berserk \
     --collection characters \
     --file berserk_characters.json \
     --jsonArray

   mongoimport \
     --db berserk \
     --collection operator_docs \
     --file berserk.operator_docs.json \
     --jsonArray
