class Filer

  require 'NaServer'
  require 'filer_aggr.rb'
  require 'filer_vol.rb'
  require 'filer_exports.rb'

  # Initialize your Filer object and establish a connection to the filer API
  #
  # == Parameters
  # Take a hash of params{'name' => 'myfiler', 'user' => "abc123", ...}
  # Required params:
  #  name -- name of the filer (must resolve to an IP)
  #  user -- username to log in with
  #  password -- password to log in with
  # Optional params:
  #  transport -- HTTP or HTTPS (default HTTP)
  #  port -- port to connect on -- default to 80 if HTTP or 443 if HTTPS
  #
  # == Returns
  # A 'Filer' object which can be used for sending commands to or getting information
  # from a filer
  def initialize(params)
    @filer = NaServer.new(params['name'], 1, 1)
    @filer.set_server_type("Filer")
    @filer.set_admin_user(params['user'], params['password'])
    @filer.set_transport_type(params['transport'] || "HTTP")
    @filer.set_port(params['port'] || @filer.get_transport_type == "HTTP" ? 80 : 443)
    @filer.set_style("LOGIN")
  end

  # Get the OnTap version of the filer
  # == Returns
  # A string with the version ID
  def version
    output = @filer.invoke("system-get-version")
    if(output.results_errno() != 0)
      r = output.results_reason()
      raise "Failed : \n" + r
    else 
      output.child_get_string("version")
    end
  end # def version

  # Get information about this filer
  # == Returns
  # Hash object containing lots of info
  #   system-name, system-id, system-model, system-serial-number, partner-system-name, etc.
  def info
    info = Hash.new
    output = @filer.invoke("system-get-info")
    if(output.results_errno() != 0)
      r = output.results_reason()
      raise "Failed : \n" + r
    else 
      output.children_get[0].children_get.each do |naelem|
        info[naelem.name] = naelem.content
      end
    end
    info
  end # def info

end