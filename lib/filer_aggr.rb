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
  #                 fast -- only use FC or SAS; cheap -- only use SATA
  # == Returns
  # Aggregate name
  def aggr_most_avail(type = "fast")
    aggrs = aggr_info
    best = nil
    besthas = 0
    aggrs.each_key do |aggrname|
      # kludge -- use the aggrname pattern to determine if this is SATA
      next if (type == "fast") and (aggrname =~ /aggr(2000|1000|500)\w/)
      next if (type == "cheap") and (aggrname !~ /aggr(2000|1000|500)\w/)
      if aggrs[aggrname]['size-available'].to_i > besthas
        best = aggrname 
        besthas = aggrs[aggrname]['size-available'].to_i
      end
    end
    best
  end

end