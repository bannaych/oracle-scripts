
docker run -d --name oraclone1 -p 1523:1521 --volume-driver pure -v oraclone1:/opt/oracle/oradata container-registry.oracle.com/database/enterprise:19.3.0.0
