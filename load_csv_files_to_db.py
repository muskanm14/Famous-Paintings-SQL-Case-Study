import pandas as pd
from sqlalchemy import create_engine

connection_string = 'postgresql://muskan:000000@localhost/paintings'
db = create_engine(connection_string)
connection = db.connect()


files = ['artist', 'canvas_size', 'image_link', 'museum_hours', 'museum', 'product_size', 'subject', 'work']

for file in files:
    df = pd.read_csv(f'/Users/mumahesh/OneDrive - Capgemini/Famous_Paintings_SQL_CaseStudy/dataset/{file}.csv')
    df.to_sql(file, con=connection, if_exists='replace', index=False)

