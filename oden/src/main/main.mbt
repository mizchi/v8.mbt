///|
extern "C" fn exit(code : Int) = "exit"

///|
async fn write_stderr_line(text : String) -> Unit {
  @stdio.stderr.write(text + "\n")
}

///|
async fn main {
  match @oden.route_cli(@env.args()[1:].to_array()) {
    Ok(@oden.OdenCliRoute::Help) => println(@oden.help_text())
    Ok(@oden.OdenCliRoute::Version) => println(@oden.version_text())
    Ok(@oden.OdenCliRoute::Plan(plan)) => println(@oden.plan_json(plan))
    Ok(@oden.OdenCliRoute::Manifest) =>
      match @oden.cli_manifest_json() {
        Ok(value) => println(value)
        Err(err) => {
          write_stderr_line(err.to_string())
          exit(1)
        }
      }
    Ok(@oden.OdenCliRoute::Exec(plan)) => {
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
      write_stderr_line(@oden.help_text())
      exit(2)
    }
  }
}
