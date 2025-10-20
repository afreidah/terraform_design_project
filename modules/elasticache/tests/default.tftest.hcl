# ----------------------------------------------------------------
# <multiline file header here>
# ----------------------------------------------------------------

test {
  parallel = true
}

# --- Global Variables ---
variables {
  global_value = "some value"
}

# --- Test <thing> ---
run "run_block_one" {

  # --- Local override variables ---
  variables {
    local_value = var.global_value
  }

  # --- Assert <thing> ---
  assert {
    condition     = aws_s3_bucket.bucket.bucket == "test-bucket"
    error_message = "S3 bucket name did not match expected"
  }
}

run "run_block_two" {

  # --- Local override variables ---
  variables {
    local_value = run.run_block_one.output_one
  }

  # --- Assert <thing> ---
  assert {
    condition     = aws_s3_bucket.bucket.bucket == "test-bucket"
    error_message = "S3 bucket name did not match expected"
  }
}
