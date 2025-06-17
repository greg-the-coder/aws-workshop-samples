# Working with AWS Services

In this module, you'll learn how to interact with AWS services from your cloud development environment and build a simple serverless application.

## Setting up AWS CLI and Credentials

Your development environment already has the AWS CLI installed. Let's configure it with the appropriate credentials.

### Option 1: Using AWS IAM Role (Recommended)

Your Coder workspace is already configured with an IAM role that has the necessary permissions for this workshop. You can verify this by running:

```bash
aws sts get-caller-identity
```

You should see output similar to:

```json
{
    "UserId": "AROAXXXXXXXXXXXXXXXXX:i-0123456789abcdef0",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/coder-workspace-role/i-0123456789abcdef0"
}
```

### Option 2: Using AWS Access Keys

If you need to use specific AWS credentials, you can configure them using:

```bash
aws configure
```

You'll be prompted to enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name (e.g., us-east-1)
- Default output format (json)

## Interacting with AWS Services

Let's practice interacting with some common AWS services using the AWS CLI.

### Amazon S3

Create a bucket:

```bash
export BUCKET_NAME=coder-workshop-$(whoami)-$(date +%s)
aws s3 mb s3://$BUCKET_NAME
```

Upload a file:

```bash
echo "Hello from Coder!" > hello.txt
aws s3 cp hello.txt s3://$BUCKET_NAME/
```

List objects in the bucket:

```bash
aws s3 ls s3://$BUCKET_NAME/
```

### Amazon DynamoDB

Create a table:

```bash
aws dynamodb create-table \
    --table-name WorkshopUsers \
    --attribute-definitions AttributeName=UserId,AttributeType=S \
    --key-schema AttributeName=UserId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

Add an item:

```bash
aws dynamodb put-item \
    --table-name WorkshopUsers \
    --item '{"UserId": {"S": "user1"}, "Name": {"S": "Workshop User"}, "Email": {"S": "user@example.com"}}'
```

Query the table:

```bash
aws dynamodb get-item \
    --table-name WorkshopUsers \
    --key '{"UserId": {"S": "user1"}}'
```

## Building a Serverless Application

Now, let's build a simple serverless application using AWS Lambda, API Gateway, and DynamoDB.

### Step 1: Create a Lambda Function

Create a new directory for your project:

```bash
mkdir -p ~/serverless-app/src
cd ~/serverless-app
```

Create a Lambda function in `src/index.js`:

```bash
cat > src/index.js << 'EOF'
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const method = event.httpMethod;
    const path = event.path;
    
    // GET /users
    if (method === 'GET' && path === '/users') {
        const params = {
            TableName: 'WorkshopUsers'
        };
        
        try {
            const result = await dynamodb.scan(params).promise();
            return {
                statusCode: 200,
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(result.Items)
            };
        } catch (error) {
            console.error('Error:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: 'Failed to retrieve users' })
            };
        }
    }
    
    // POST /users
    if (method === 'POST' && path === '/users') {
        const user = JSON.parse(event.body);
        
        if (!user.userId || !user.name) {
            return {
                statusCode: 400,
                body: JSON.stringify({ error: 'userId and name are required' })
            };
        }
        
        const params = {
            TableName: 'WorkshopUsers',
            Item: {
                UserId: user.userId,
                Name: user.name,
                Email: user.email || null,
                CreatedAt: new Date().toISOString()
            }
        };
        
        try {
            await dynamodb.put(params).promise();
            return {
                statusCode: 201,
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(params.Item)
            };
        } catch (error) {
            console.error('Error:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: 'Failed to create user' })
            };
        }
    }
    
    // GET /users/{userId}
    if (method === 'GET' && path.startsWith('/users/')) {
        const userId = path.split('/')[2];
        
        const params = {
            TableName: 'WorkshopUsers',
            Key: {
                UserId: userId
            }
        };
        
        try {
            const result = await dynamodb.get(params).promise();
            
            if (!result.Item) {
                return {
                    statusCode: 404,
                    body: JSON.stringify({ error: 'User not found' })
                };
            }
            
            return {
                statusCode: 200,
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(result.Item)
            };
        } catch (error) {
            console.error('Error:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: 'Failed to retrieve user' })
            };
        }
    }
    
    return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Not found' })
    };
};
EOF
```

Create a `package.json` file:

```bash
cat > package.json << 'EOF'
{
  "name": "serverless-app",
  "version": "1.0.0",
  "description": "Simple serverless application for Coder workshop",
  "main": "src/index.js",
  "dependencies": {
    "aws-sdk": "^2.1048.0"
  }
}
EOF
```

Install dependencies:

```bash
npm install
```

### Step 2: Package the Lambda Function

Create a deployment package:

```bash
zip -r function.zip src package.json node_modules
```

### Step 3: Create an IAM Role for Lambda

Create a trust policy:

```bash
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create the role:

```bash
aws iam create-role \
    --role-name workshop-lambda-role \
    --assume-role-policy-document file://trust-policy.json
```

Attach policies:

```bash
aws iam attach-role-policy \
    --role-name workshop-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
    --role-name workshop-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
```

### Step 4: Create the Lambda Function

```bash
aws lambda create-function \
    --function-name workshop-users-api \
    --runtime nodejs16.x \
    --handler src/index.handler \
    --role $(aws iam get-role --role-name workshop-lambda-role --query 'Role.Arn' --output text) \
    --zip-file fileb://function.zip
```

### Step 5: Create API Gateway

Create an API:

```bash
aws apigateway create-rest-api \
    --name workshop-api \
    --endpoint-configuration types=REGIONAL
```

Get the API ID:

```bash
export API_ID=$(aws apigateway get-rest-apis --query 'items[?name==`workshop-api`].id' --output text)
```

Get the root resource ID:

```bash
export ROOT_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[?path==`/`].id' --output text)
```

Create a resource for /users:

```bash
aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part users
```

Get the users resource ID:

```bash
export USERS_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[?path==`/users`].id' --output text)
```

Create methods for the /users resource:

```bash
# GET method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $USERS_RESOURCE_ID \
    --http-method GET \
    --authorization-type NONE

# POST method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $USERS_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE
```

### Step 6: Deploy the API

Create a deployment:

```bash
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name dev
```

Get the API URL:

```bash
echo "API URL: https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/dev"
```

### Step 7: Test the API

Create a user:

```bash
curl -X POST \
  https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/dev/users \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "user2",
    "name": "Workshop User 2",
    "email": "user2@example.com"
  }'
```

Get all users:

```bash
curl -X GET \
  https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/dev/users
```

Get a specific user:

```bash
curl -X GET \
  https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/dev/users/user2
```

## Clean Up

When you're done with this module, you can clean up the resources you created:

```bash
# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id $API_ID

# Delete Lambda function
aws lambda delete-function --function-name workshop-users-api

# Delete IAM role and policies
aws iam detach-role-policy \
    --role-name workshop-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam detach-role-policy \
    --role-name workshop-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

aws iam delete-role --role-name workshop-lambda-role

# Delete DynamoDB table
aws dynamodb delete-table --table-name WorkshopUsers

# Delete S3 bucket
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME
```

## Next Steps

In the next module, we'll explore [Advanced Development Environments](../04-advanced-environments/README.md), including Windows development with NICE DCV and GPU-accelerated environments.
