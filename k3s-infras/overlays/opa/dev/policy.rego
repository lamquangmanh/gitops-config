package authz

default allow = false

# Main rule
allow {
  user_has_permission
}

# Validate token with User Service
user_has_permission {
  some resp
  token := trim(split(input.headers.Authorization, " ")[1])
  resp := http.send({
    "method": "POST",
    "url": "http://auth-be-svc.backend-dev.svc.cluster.local/auth/verify",
    "headers": {
      "Authorization": input.headers.Authorization
    },
    "body": {
      "accessToken": token,
      "requestType": is_graphql_request ? "GRAPHQL" : "VIEW",
      "url": input.path,
      "method": input.method, 
    }
  })
  resp.data.success == true
}

user_has_permission {
  is_graphql_request
  allowed_graphql_operation
}

# Detect GraphQL by looking for a body with "query"
is_graphql_request {
  input.parsed_body.query
}

# Match GraphQL operation name or content
allowed_graphql_operation {
  contains(lower(input.parsed_body.query), "query")
}

allowed_graphql_operation {
  contains(lower(input.parsed_body.query), "mutation")
}
