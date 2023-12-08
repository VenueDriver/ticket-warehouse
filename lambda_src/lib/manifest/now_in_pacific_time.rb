module NowInPacificTime
  extend self
  def now_in_pacific_time
    tz = TZInfo::Timezone.get('America/Los_Angeles')
    
    in_pacific_time = tz.to_local(Time.now)
    in_pacific_time.strftime("Generated on %A, %B %-d, %Y at %I:%M%p Pacific") 
  end
end