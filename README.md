# MySQL S3 Backup

A Ruby script to backup, gzip, and upload a defined set of databaset to Amazon AWS S3 bucket.


### Getting Started

Install gems:
`bundle install`

Copy and add your database & S3 info:
`cp secrets.yml.sample secrets.yml`

Give it a go:
`ruby backup.rb`


### Advanced Options
!!TODO!!
This script supports multiple app environments. You can pass these along through the `APP_ENV` argument, e.g.
`ruby backup.rb APP_ENV=production`

!!TODO!!
You can pass `DEBUG` argument to have it test and run through the process wihtout uploading to S3


### Credit

Created by [Greg Leuch][gleuch] ([@gleuch][twitter]).
Copyright 2014 by [XOlator][xolator]. Free for use, please attribute.


[gleuch]: http://gleu.ch
[twitter]: https://twitter.com/gleuch
[xolator]: http://xolator.com