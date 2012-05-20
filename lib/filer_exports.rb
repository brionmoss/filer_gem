class Filer

  # Add a rule to the exports file.  Do NOTHING if there is already a rule for this path
  # == Parameters
  # Hash {"path" => "/vol/what/ever", "rw" => "list...", "ro" => "list...", "root" => "list..."}
  # Note that at least one of rw or ro has to be specified; root is optional
  def exports_add(params)
    exports = exports_list
    if exports[params['path']]
      if exports[params['path']]['ro'] == params['ro'] and
        exports[params['path']]['rw'] == params['rw'] and
        exports[params['path']]['root'] == params['root']
        puts "Not setting export for #{params['path']} -- it's already done"
        return
      else
        puts "Not setting export for #{params['path']} -- leaving conflicting setting"
        return
      end
    end

    exports_rule_info = NaElement.new("exports-rule-info")
    exports_rule_info.child_add_string("pathname",params['path'])

    if params['rw']
      rw = NaElement.new("read-write")
      params['rw'].split(":").each do |host|
        rw_host = NaElement.new("exports-hostname-info")
        rw_host.child_add_string("name",host)
        rw.child_add(rw_host)      
      end
      exports_rule_info.child_add(rw)
    end

    if params['ro']
      ro = NaElement.new("read-only")
      params['ro'].split(":").each do |host|
        ro_host = NaElement.new("exports-hostname-info")
        ro_host.child_add_string("name",host)
        ro.child_add(ro_host)
      end
      exports_rule_info.child_add(ro)
    end

    if params['root']
      root = NaElement.new("root")
      params['root'].split(":").each do |host|
        root_host = NaElement.new("exports-hostname-info")
        root_host.child_add_string("name",host)
        root.child_add(root_host)
      end
      exports_rule_info.child_add(root)
    end

    rules = NaElement.new("rules")
    rules.child_add(exports_rule_info)

    append = NaElement.new("nfs-exportfs-append-rules")
    append.child_add_string("persistent",true)
    append.child_add(rules)
    append.child_add_string("verbose",true)

    output = @filer.invoke_elem(append)
    if (output.results_status() == "failed")
      raise "Error #{output.results_errno} #{output.results_reason()}\n"
    else
      puts "Set export rights for #{params['path']}"
    end               
  end # def exports_add

  # Get a list of exports
  # == Returns
  # Hash of exports, which will look something like
  # {
  #   "/vol/path/one"  => { "ro" => "1.2.3.4", "root" => "1.2.3.4" },
  #   "/vol/other/dir" => { "rw" => "5.6.7.8" }
  # }
  def exports_list
    exports = Hash.new
    out = @filer.invoke( "nfs-exportfs-list-rules" )
    export_info = out.child_get("rules")
    result = export_info.children_get()
    result.each do |export|
      path_name = export.child_get_string("pathname")
      rw_list = []
      ro_list = []
      root_list = []
      if(export.child_get("read-only"))
        ro_results = export.child_get("read-only")
        ro_hosts = ro_results.children_get()
        ro_hosts.each do |ro|
          if(ro.child_get_string("all-hosts"))
            all_hosts = ro.child_get_string("all-hosts")
            if(all_hosts == "true") 
              ro_list << "all-hosts"
              break
            end
          elsif(ro.child_get_string("name")) 
            host_name = ro.child_get_string("name")
            ro_list << host_name
          end
        end
      end			
      if(export.child_get("read-write"))
        rw_results = export.child_get("read-write")
        rw_hosts = rw_results.children_get()                
        rw_hosts.each do |rw|
          if(rw.child_get_string("all-hosts"))
            all_hosts = rw.child_get_string("all-hosts")
            if(all_hosts == "true") 
              rw_list << "all-hosts"
              break
            end						
          elsif(rw.child_get_string("name"))
            host_name = rw.child_get_string("name")
            rw_list << host_name
          end
        end
      end			
      if(export.child_get("root"))
        root_results = export.child_get("root")
        root_hosts = root_results.children_get()
        root_hosts.each do |root|
          if(root.child_get_string("all-hosts"))
            all_hosts = root.child_get_string("all-hosts")
            if(all_hosts == "true")
              root_list << "all-hosts"
              break
            end
          elsif(root.child_get_string("name"))
            host_name = root.child_get_string("name")
            root_list << host_name
          end
        end
      end
      exports[path_name] = Hash.new
      unless(ro_list.empty?) 
        exports[path_name]['ro'] = ro_list.join(":")
      end
      unless(rw_list.empty?) 
        exports[path_name]['rw'] = rw_list.join(":")
      end
      unless(root_list.empty?)
        exports[path_name]['root'] = root_list.join(":")
      end
    end
    exports
  end # def exports_list

end