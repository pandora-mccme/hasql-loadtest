CREATE TABLE IF NOT EXISTS objects (
    id SERIAL PRIMARY KEY
  , name text NOT NULL
  , color text
  , background text
  , orderc int UNIQUE NOT NULL
  , flag bool NOT NULL DEFAULT true
  );

INSERT INTO objects (name, color, background, orderc, flag)
  VALUES ('name1', 'rgb(0,0,0)', 'rgb(255,255,255)', 1, 'f')
       , ('name2', 'rgb(255,0,0)', 'rgb(255,255,255)', 2, 't')
       , ('name3', 'rgb(0,255,0)', 'rgb(255,255,255)', 3, 't')
       , ('name4', 'rgb(0,0,255)', null, 4, 't')
       , ('name5', 'rgb(255,0,255)', 'rgb(255,255,255)', 5, 't')
       , ('name6', 'rgb(0,255,255)', 'rgb(255,255,255)', 6, 'f')
       , ('name7', 'rgb(255,255,0)', null, 7, 't')
  ON CONFLICT DO NOTHING;
