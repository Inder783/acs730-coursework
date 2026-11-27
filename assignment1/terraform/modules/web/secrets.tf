data "aws_ssm_parameter" "db_password" {
  name            = "/acs730/assignment1/db-password"
  with_decryption = true
}
