///|
async fn main {
  let args = @env.args()
  let code = @cli.run(@cli.parse_arguments(args[1:].to_owned())) catch {
    @liberty.LibertyError(_, _, _) as error => {
      @stdio.stderr.write(error.render() + "\n") catch {
        _ => ()
      }
      2
    }
    error => {
      @stdio.stderr.write(error.to_string() + "\n") catch {
        _ => ()
      }
      2
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}
