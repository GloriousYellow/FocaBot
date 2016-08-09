VideoDownload = require './download'
moment = require 'moment'

class AudioModuleCommands
  constructor: (@audioModule)->
    { @engine } = @audioModule
    {@bot, @commands, @permissions, @getServerData} = @engine

    # Play
    @playCommand = @commands.registerCommand 'play', {
      description: 'Adds a song to the queue. (You need to be in a voice channel)'
      argSeparator: '|'
    }, (msg,args)=>
      return @bot.reply msg, 'No video specified.' if not args[0].trim()
      return @bot.reply msg, 'You must be in a voice channel to request songs.' if not msg.author.voiceChannel
      dl = new VideoDownload args[0]
      dl.on 'info', (info)=>
        @audioModule.handleVideoInfo dl, msg, args
      dl.on 'error', (err)=>
        @bot.sendMessage msg.channel, 'Something went wrong.'
    
    # Skip
    @skipCommand = @commands.registerCommand 'skip', {
      description: 'Skips currently playing song.'
      adminOnly: true
    }, (msg)=>
      {queue} = @getServerData(msg.server)
      if queue.items.length or queue.currentItem
        @bot.sendMessage msg.channel, "**#{msg.author.username}** skipped the current song."
        queue.nextItem()
      else
        @bot.sendMessage msg.channel, 'No songs playing on the current server.'

    # Stop
    @stopCommand = @commands.registerCommand 'stop', {
        description: 'Stops current playback and clears the queue.'
        adminOnly: true
    }, (msg)=>
      {queue} = @getServerData(msg.server)
      if queue.currentItem
        queue.clearQueue()
        @bot.sendMessage msg.channel, "**#{msg.author.username}** cleared the queue."
      else
        @bot.sendMessage msg.channel, "No songs playing on the current server."

    # Pause and Resume
    @pauseCommand = @commands.registerCommand 'pause', {
      description: 'Pauses audio playback.'
      adminOnly: true
    }, (msg)=>
      {audioPlayer} = @getServerData(msg.server)
      if audioPlayer.currentStream
        audioPlayer.pause()
        @bot.sendMessage msg.channel, "**#{msg.author.username}** paused audio playback."
      else
        @bot.sendMessage msg.channel, "Nothing to pause."
    @resumeCommand = @commands.registerCommand 'resume', {
      description: 'Resumes audio playback.'
      adminOnly: true
    }, (msg)=>
      {audioPlayer} = @getServerData(msg.server)
      if audioPlayer.currentStream
        audioPlayer.resume()
        @bot.sendMessage msg.channel, "**#{msg.author.username}** resumed audio playback."
      else
        @bot.sendMessage msg.channel, "Nothing to resume."

    # Volume
    @volumeCommand = @commands.registerCommand 'volume', {
      description: 'Sets the volume'
      adminOnly: true
    }, (msg, args)=>
      {audioPlayer} = @getServerData(msg.server)
      if not args
        return @bot.sendMessage msg.channel, "Current Volume: #{audioPlayer.volume*100}."
      limit = if @permissions.isOwner msg.author then 500 else 100
      volume = parseInt(args)
      if volume > 0 and volume <= limit
        audioPlayer.setVolume volume/100
        @bot.sendMessage msg.channel, "**#{msg.author.username}** set the volume to #{volume}."
      else
        @bot.sendMessage msg.channel, "Invalid volume provided."

    # Queue
    @queueCommand = @commands.registerCommand 'queue', {
      description: 'Displays the current queue.'
    }, (msg, args)=>
      {audioPlayer, queue} = @getServerData(msg.server)
      return @bot.sendMessage msg.channel, "Nothing being played on the current server." if not queue.currentItem
      qI = queue.currentItem
      currentTime = moment.duration audioPlayer.voiceConnection.streamTime
      currentTime = "#{currentTime.minutes()}:#{currentTime.seconds()}"
      reply = """
      **Now Playing In** `#{qI.playInChannel.name}`: 
      `#{qI.title}` (#{currentTime}/#{qI.duration}) Requested By #{qI.requestedBy.username}\n
      """
      if queue.items.length
        reply += "**Up next:**\n"
        l = queue.items.length
        i = 0
        for qi in queue.items when i < 20
          reply += "**#{++i}.** `#{qi.title}` (#{qi.duration}) Requested By #{qi.requestedBy.username}\n"
        if l > 10
          reply += "*(#{l-i} more...)*"
      else
         reply += "Queue is currently empty."
      @bot.sendMessage msg.channel, reply

    # Undo
    @undoCommand = @commands.registerCommand 'undo', {
      description: 'Removes the last item from the queue.'
    }, (msg, args)=>
      {queue} = @getServerData msg.server
      if not queue.items.length and not queue.currentItem
        return @bot.sendMessage msg.channel, 'The queue is empty.'

      [..., last] = queue.items
      last = queue.currentItem if not last
      if last.requestedBy.id is msg.author.id or @permissions.isAdmin msg.author, msg.server
        queue.undo()
        @bot.sendMessage msg.channel, "**#{msg.author.username}** removed the last item from the queue."
      else
        @bot.sendMessage msg.channel, 'You can only remove your own items from the queue.'

    # Shuffle
    @shuffleCommand = @commands.registerCommand 'shuffle', {
      description: 'Shuffles the queue.'
      adminOnly: true
    }, (msg,args)=>
      {queue} = @getServerData msg.server
      if queue.items.length
        queue.shuffle()
        @bot.sendMessage msg.channel, '✅'
      else
        @bot.sendMessage msg.channel, 'The queue is empty.'

  unregisterAll: =>
    @commands.unregisterCommands [
      @playCommand
      @skipCommand
      @stopCommand
      @pauseCommand
      @resumeCommand
      @volumeCommand
      @queueCommand
      @undoCommand
      @shuffleCommand
    ]

module.exports = AudioModuleCommands
