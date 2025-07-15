## Running the docker container 

SETUP
```
Copy docker-compose-template  into  docker-compose.yaml

fill in the 3 ENV variables (ARGS).  DSN is the supabase (Psql) connection string.  Network name is like 'mainnet' or 'base'.  Substreams API key is self explanitory.  
```

BUILD 

```

docker compose build 

docker compose up  (-d) 

```
