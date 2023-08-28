# POC FLUTTER UPLOAD CHUNK FLUTTER

How to run:
SERVER:
on your terminal execute the following.
install node:  v18.16.0
> cd upload_server && npm install && cd ..
on project root.
> node upload_server/index.js 

APP:
1. fvm use 3.10.6
2. run the main.dart

Press on upload button and select a file.
when a file is sent it will be received written in upload_server/images.
canceling an uploaded file will also delete all chunks.