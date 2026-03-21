///|
extern "C" fn exit(code : Int) = "exit"

///|
async fn write_stderr_line(text : String) -> Unit {
  @stdio.stderr.write(text + "\n")
}

///|
async fn main {
  match @oden_lib.route_cli(@env.args()[1:].to_array()) {
    Ok(@oden_lib.OdenCliRoute::Help) => println(@oden_lib.help_text())
    Ok(@oden_lib.OdenCliRoute::Version) => println(@oden_lib.version_text())
    Ok(@oden_lib.OdenCliRoute::Plan(plan)) => println(@oden_lib.plan_json(plan))
    Ok(@oden_lib.OdenCliRoute::Manifest) =>
      match @oden_lib.cli_manifest_json() {
        Ok(value) => println(value)
        Err(err) => {
          write_stderr_line(err.to_string())
          exit(1)
        }
      }
    Ok(@oden_lib.OdenCliRoute::Exec(plan)) => {
      ignore(@v8.version())
      let exit_code = match execute_run_plan(plan) {
        Ok(code) => code
        Err(err) => {
          write_stderr_line(err.to_string())
          exit(1)
          1
        }
      }
      if exit_code != 0 {
        exit(exit_code)
      }
    }
    Err(err) => {
      write_stderr_line(err)
      write_stderr_line(@oden_lib.help_text())
      exit(2)
    }
  }
}
