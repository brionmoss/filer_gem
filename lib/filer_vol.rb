class Filer
  
  # Get a list of volumes
  # == Returns
  # Array of volumes on the filer
  def vol_list
    volumes = []
    iter = @filer.invoke( "volume-list-info-iter-start" )
    if (iter.results_status() == "failed")
      raise "Error #{iter.results_errno} listing volumes: #{iter.results_reason()}\n"
    end
    volcount = iter.child_get_string("records")
    start_tag = iter.child_get_string("tag")
    vols = @filer.invoke("volume-list-info-iter-next", "tag", start_tag, "maximum",volcount)
    unless vols.child_get_string("records") == volcount
      raise "Error -- problem getting full volume list.  Got #{vols.child_get_string("records")}, expected #{volcount}"
    end
    vols.child_get("volumes").children_get.each do |vol| 
      volumes << vol.child_get_string("name") if vol.child_get_string("state") == "online"
    end
    @filer.invoke("volume-list-info-iter-end", "tag", start_tag)
    volumes.sort
  end
  
  # Get information about a volume
  # == Parameters
  # Volume name (e.g. "vol0")
  # == Returns
  # Hash object containing info about the volume
  # {"plexes"=>"", "is-invalid"=>"false", "space-reserve-enabled"=>"true", "files-private-used"=>"577", "name"=>"vol0", "raid-status"=>"raid_dp,sis", "compression-info"=>"", "inodefile-private-capacity"=>"31142", "files-used"=>"7958", "is-unrecoverable"=>"false", "containing-aggregate"=>"c01aggr300a", "is-snaplock"=>"false", "inodefile-public-capacity"=>"31142", "size-used"=>"42183372800", "snapshot-percent-reserved"=>"0", "uuid"=>"42f54314-78e3-11e0-87ba-00a0980b5743", "reserve-used-actual"=>"0", "size-total"=>"151397597184", "quota-init"=>"0", "files-total"=>"4389260", "percentage-used"=>"28", "mirror-status"=>"unmirrored", "is-inconsistent"=>"false", "is-checksum-enabled"=>"true", "raid-size"=>"27", "reserve"=>"45056", "type"=>"flex", "sis"=>"", "reserve-used"=>"0", "reserve-required"=>"45056", "size-available"=>"109214093312", "snapshot-blocks-reserved"=>"0", "block-type"=>"64_bit", "disk-count"=>"152", "is-in-snapmirror-jumpahead"=>"false", "checksum-style"=>"block", "plex-count"=>"1", "space-reserve"=>"volume", "state"=>"online"}
  def vol_info(volname)
    info = Hash.new
    output = @filer.invoke( "volume-list-info","volume", volname )
    if (output.results_status() == "failed")
      raise "Error #{output.results_errno} #{output.results_reason()}\n"
    end
    output.child_get("volumes").children_get().each do |vol|
      vol.children_get.each do |naelem|
        info[naelem.name] = naelem.content
      end
    end
    info
  end # def vol_info

  # Create a new volume
  # == Parameters
  # Hash of params
  # Required:
  #   name -- name of the volume
  #   size -- size (in any format the filer will accept) 
  # Optional:
  #   aggr -- aggregate in which to create this volume.  Defaults to using disktype
  #   disktype -- "fast", "cheap", or "any" -- pick the least full aggregate of the
  #               corresponding type (fast = FC or SAS, cheap = SATA)
  #               defaults to "fast"
  #               disktype is ignored if a specific aggregate is given
  #   qtree -- a qtree to create in the volume
  #   qtype -- qtree security type (if we're creating a qtree) -- if not set leave default
  #   reserve -- specify space reservation (none/file/volume)  Defaults to volume
  #   snap_reserve -- sets the % snapshot reserve.  Default to 0
  #   fractional_reserve -- sets the % snapshot reserve.  Default to 0
  def vol_create(params)
    # if an aggregate has not been specified, pick one
    unless params['aggr']
      params['aggr'] = aggr_most_avail(params['disktype'] || "fast")
    end
    # if we couldn't find one, there must not be one of the right type.
    # Retry with disktype of "any" if one wasn't specified explicitly
    unless params['aggr'] or params['disktype']
      params['aggr'] = aggr_most_avail("any")
    end
    # check that we got a valid size
    unless params['size'] =~ /^(\d+)[tgm]$/
    	puts "Invalid size specified (-s $SIZE)"
    	puts "The size should be a number followed by a "
    	puts "   t (terrabytes),"
    	puts "   g (gigabytes), or "
    	puts "   m (megabytes)"
    	puts "For example, 150g or 500m"
      exit
    end
    unless params['name'] =~ /^[A-Za-z_][A-Za-z0-9_]+$/
      raise "Error in vol_create -- invalid volume name #{params['name']} (letters, numbers and underscore only; must begin with letter or underscore)"
    end
    if params['disktype'] and not ["fast","cheap","any"].include?(params['disktype'])
      raise "Error in vol_create -- unknown disktype #{params['disktype']} (must be fast/cheap/any)"
    end
    if params['qtype'] and not ["unix","ntfs","mixed"].include?(params['qtype'])
      raise "Error in vol_create -- unknown qtree security stype #{params['qtype']} (must be unix/ntfs/mixed)"
    end
    if params['reserve'] and not ["none","file","volume"].include?(params["reserve"])
      raise "Error in vol_create -- unknown reserve setting #{params['reserve']} (must be volume/file/none)"
    end
    if params['snap_reserve'] and not (0..100) === params['snap_reserve'].to_i 
      raise "Error in vol_create -- invalid reserve #{params['snap_reserve']} (must be number between 0 and 100)"
    end
    if params['fractional_reserve'] and not (0..100) === params['reserve'].to_i 
      raise "Error in vol_create -- invalid fractional_reserve #{params['fractional_reserve']} (must be number between 0 and 100)"
    end
    
    # create the volume
    output = @filer.invoke("volume-create",
    "containing-aggr-name", params['aggr'],
    "language-code", "C",
    "size", params['size'],
    "space-reserve", params['reserve'] || "volume",
    "volume", params['name']
    )
    if (output.results_status() == "failed")
      if output.results_errno.to_i == 17
        # this one is non-fatal. Print a message but continue.
        puts "Warning: couldn't create volume #{params['name']} -- volume already exists"
      else
        raise "Error #{output.results_errno} #{output.results_reason()}\n"
      end
    else
      puts "Created volume #{params['name']}"
    end

    # set standard options
    vol_option(params['name'],"no_atime_update","on")
    vol_option(params['name'],"fractional_reserve",params['fractional_reserve'] || "0")

    # set the snapshot reserve
    output = @filer.invoke("snapshot-set-reserve","volume",params['name'],"percentage",params['snap_reserve'] || "0")
    if (output.results_status() == "failed")
      raise "Error #{output.results_errno} #{output.results_reason()}\n"
    end
    
    # create the qtree, if we want one
    if params['qtree']
      output = @filer.invoke("qtree-create","volume",params['name'],"qtree",params['qtree'])
      if (output.results_status() == "failed")
        if output.results_errno.to_i == 13080
          puts "Warning: couldn't create qtree /vol/#{params['name']}/#{params['qtree']} -- qtree already exists"
        else
          raise "Error #{output.results_errno} #{output.results_reason()}\n"
        end
      else
        puts "Created qtree /vol/#{params['name']}/#{params['qtree']}"
      end
    end

    # There is no API call for setting qtree security style.  WTF, NetApp?
    netapp_implements_obvious_apis = false
    if netapp_implements_obvious_apis and params['qtype']
      output = @filer.invoke("qtree-set-security",
      "volume",params['name'],
      "qtree",params['qtree'],
      "security",params['qtype']
      )
      if (output.results_status() == "failed")
        raise "Error #{output.results_errno} #{output.results_reason()}\n"
      else
        puts "Set security for qtree /vol/#{params['name']}/#{params['qtree']} to #{params['qtype']}"
      end
    end

  end # def vol_create

  # Set options on a volume
  # == Parameters
  #  volume, name, value
  # For instance, to set no_atime_update to off on vol0
  #  vol_option('vol0','no_atime_update','off)
  def vol_option(volume,name,value)
    output = @filer.invoke("volume-set-option","volume",volume,
                           "option-name",name, "option-value",value)
    if (output.results_status() == "failed")
      raise "Error setting #{output.results_errno} #{output.results_reason()}\n"
    end
  end

end
