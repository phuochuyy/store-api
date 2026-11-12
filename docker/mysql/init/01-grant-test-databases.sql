-- Let the app user create and drop the test database (store_api_test) as Rails expects.
GRANT ALL PRIVILEGES ON `store_api\_%`.* TO 'store_api'@'%';
FLUSH PRIVILEGES;
