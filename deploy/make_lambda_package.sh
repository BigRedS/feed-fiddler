#! /bin/bash

set -e

# from https://docs.aws.amazon.com/lambda/latest/dg/python-package.html#python-package-create-dependencies

mkdir -p package

for p in botocore pyyaml; do
    pip3 install --target ./package $p
done

cd package
zip -r ../lambda_function.zip .

cd ..

ln -s ../feed-fiddler lambda_function.py
zip lambda_function.zip ./lambda_function.py
rm lambda_function.py
