aws-publisher
=============

aws-publisher let you upload files within a directory to your amazon s3 bucket.
- it only uploads new or modified files to your bucket.
- it sets a far expiry date and zip files

```coffee
Publisher = require 'aws-publisher'

# create s3 publisher
publisher = new Publisher bucket: 'name',  key: 'xx', secret: 'xx'

# define filter closure that will only select js, png, and css file
filter = (f, stat) -> stat.isDirectory() or /\.(js|png|css)$/.test f

# publish 'public' dir to root folder '' of the  bucket
publisher.publishDir {origin: 'public', dest: '', filter}, cb

```

