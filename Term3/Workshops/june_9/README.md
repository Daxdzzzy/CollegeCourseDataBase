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

