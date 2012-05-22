class Filer

  # Get information about an aggr
  # == Returns
  # Hash object containing info about the aggregates
  def aggr_info
    info = Hash.new
    output = @filer.invoke( "aggr-list-info" )
    if (output.results_status() == "failed")
      raise "Error #{output.results_errno} #{output.results_reason()}\n"
    end
    output.child_get("aggregates").children_get().each do |aggr|
      aggrname = aggr.child_get_string("name")
      info[aggrname] = {}
      aggr.children_get.each do |naelem|
        info[aggrname][naelem.name] = naelem.content
      end
    end
    info
  end # def aggr_info

  # Pick the aggregate that has the most available space
  # == Parameters
  # Type (optional) -- "fast", "cheap", or "any"
  #                 fast -- only use 10K RPM or faster (FC/SAS); cheap -- only use SATA (<10K RPM)
  # == Returns
  # Aggregate name
  def aggr_most_avail(want = "fast")
    aggrs = aggr_info
    aggrspeed = aggr_speed
    best = nil
    besthas = 0
    aggrs.each_key do |aggrname|
      next if (want == "fast")  and (aggrspeed[aggrname] < 10000)
      next if (want == "cheap") and (aggrspeed[aggrname] >= 10000)
      if aggrs[aggrname]['size-available'].to_i > besthas
        best = aggrname 
        besthas = aggrs[aggrname]['size-available'].to_i
      end
    end
    best
  end

  # Report the speed (in RPM) of aggregates on this filer
  # the speed of an aggregate is bound by its slowest disk
  # == Returns
  # Hash of {aggr => rpm}
  def aggr_speed
    aggr_speed = {}
    output = @filer.invoke("disk-list-info")
    if(output.results_errno() != 0)
      r = output.results_reason()
      raise "Failed : \n" + r
    else 
      output.child_get("disk-details").children_get.each do |disk| 
        speed = disk.child_get_string("rpm").to_i
        aggr = disk.child_get_string("aggregate") 
        aggr_speed[aggr] = speed if aggr and (aggr_speed[aggr].nil? or aggr_speed[aggr] > speed)
      end
    end
    aggr_speed
  end


end