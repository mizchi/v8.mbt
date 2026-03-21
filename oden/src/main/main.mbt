///|
extern "C" fn exit(code : Int) = "exit"

///|
async fn main {
  match @oden.route_cli(@env.args()[1:].to_array()) {
    Ok(@oden.OdenCliRoute::Help) => println(@oden.help_text())
    Ok(@oden.OdenCliRoute::Version) => println(@oden.version_text())
    Ok(@oden.OdenCliRoute::Manifest) =>
      match @oden.cli_manifest_json() {
        Ok(value) => println(value)
        Err(err) => {
          println(err.to_string())
          exit(1)
        }
      }
    Ok(@oden.OdenCliRoute::Exec(plan)) => {
      ignore(@v8.version())
      let exit_code = @process.run(plan.program, plan.argv) catch {
        err => {
          println(err.to_string())
          exit(1)
          1
        }
      }
      if exit_code != 0 {
        exit(exit_code)
      }
    }
    Err(err) => {
      println(err)
      println(@oden.help_text())
      exit(2)
    }
  }
}
