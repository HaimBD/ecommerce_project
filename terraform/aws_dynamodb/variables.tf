variable "table_name" {
  type        = string
  default = "orders"
  description = "DynamoDB table name."
}

variable "hash_key" {
  type        = string
  default = "order_id"
  description = "Partition key attribute name."
}

variable "hash_key_type" {
  type        = string
  default     = "S" # S | N | B
  description = "Partition key attribute type."
}

variable "billing_mode" {
  type        = string
  default     = "PAY_PER_REQUEST" # or PROVISIONED
  description = "Table billing mode."
}

variable "tags" {
  type = map(string)
  default = {
      environment = "production"
      project_name = "ecommerce"
      }
  description = "Tags to apply to the table."
}