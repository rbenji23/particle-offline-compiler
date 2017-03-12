{CompositeDisposable} = require 'atom'
{BufferedProcess} = require 'atom'

DFUManager = require './dfu-manager'

module.exports =
  packageName: require('../package.json').name
  config:
    particleRootPath:
      type: 'string'
      default: '~/github/spark-firmware/'
      description: 'Root location of the particle-firmware'
      order: 1
    particleCompilerPath:
      type: 'string'
      default: '~/github/spark-firmware/main/'
      description: 'Location from which the make file will be called (/main->user part only or /modules->user and system parts)'
      order: 2
    enableDevelop:
      type: 'boolean'
      description: 'Set PARTICLE_DEVELOP=true'
      default: true
      order: 3
    serialPort:
      type: 'string'
      default: '/dev/tty.usbmodem'
      description: 'Serial port to upload firmware binaries to (use the Particle menu to refresh and set this quickly)'
      order: 4
    enableClean:
      type: 'boolean'
      description: 'add \"clean\" to make command to force complete rebuild'
      default: false
      order: 5

  activate: ->
    @dfuMan = new DFUManager()

    atom.commands.add 'atom-workspace', "#{@packageName}:compile", => @compile(0)
    atom.commands.add 'atom-workspace', "#{@packageName}:compileDFU", => @compile(1)
    atom.commands.add 'atom-workspace', "#{@packageName}:OTAU", => @OTAU()
    atom.commands.add 'atom-workspace', "#{@packageName}:setCompileUser", => @setCompilerBase('main')
    atom.commands.add 'atom-workspace', "#{@packageName}:setCompileUserSystem", => @setCompilerBase('modules')
    atom.commands.add 'atom-workspace', "#{@packageName}:setCompileBootloader", => @setCompilerBase('bootloader')
    atom.commands.add 'atom-workspace', "#{@packageName}:getPorts", => @dfuMan.getPorts()
    atom.commands.add 'atom-workspace', "#{@packageName}:setUseClean", => @setClean(true)
    atom.commands.add 'atom-workspace', "#{@packageName}:setDontUseClean", => @setClean(false)

    # populate DFU serial device list upon activation
    @dfuMan.getPorts()

  consumeConsolePanel: (@consolePanel) ->

  consumeProfiles: (@profileManager) ->
    console.log(@profileManager.currentProfile)

  consumeToolBar: (toolBar) ->
    @toolBar = toolBar @packageName
    @toolBarButton = @toolBar.addButton
    	icon: 'checkmark-circled'
    	callback: "#{@packageName}:compileDFU"
    	tooltip: 'Compile locally'
    	iconset: 'ion'
    	priority: 52

  compile: (doUpload)->
    console.log(@profileManager.currentProfile)
    #@cwd = atom.project.getPaths()[0]
    @compilerPath = atom.config.get("#{@packageName}.particleCompilerPath")
    @platform = @profileManager.currentTargetPlatform #pull selected device from particle profileManager
    @develop = atom.config.get("#{@packageName}.enableDevelop")
    @clean = atom.config.get("#{@packageName}.enableClean")
    @app = atom.workspace.getActivePaneItem().buffer.file.getParent().getBaseName()

    command = 'make'
    args = [
      'all',
      '-C', @compilerPath,
      'APP='+@app,
      #'APPDIR='+@cwd,
      #'TARGET_DIR='+@cwd+'/firmware/'+@platform,
      'PLATFORM_ID='+@platform,
      'PARTICLE_DEVELOP='+@develop,
    ]

    #add "clean" if selected
    if (@clean)
      args.unshift 'clean'

    # append addition upload instructions if set by user
    if (doUpload == 1)
      @serialPort = atom.config.get("#{@packageName}.serialPort")
      args.push 'PARTICLE_SERIAL_DEV='+@serialPort
      args.push 'program-dfu'

    console.clear();
    @consolePanel.clear()

    # debug to console
    stdout = (output) ->
      console.log("[compile] STDOUT:", output)
      @consolePanel.log("[compile] STDOUT:"+output.toString())
    stderr = (err) ->
      console.log("[compile] STDERR:", err)
      @consolePanel.warn("[compile] STDERR:"+err.toString())
    exit = (code) ->
      console.log("[compile] Exited with #{code}")
      if code == 0
        @consolePanel.notice("[compile] Exited with #{code}")
      else
        @consolePanel.error("[compile] Exited with #{code}")

    console.log("[compile] Command:", command,args.join(' '))
    @consolePanel.log("[compile] Command: "+command+" "+args.join(' '))

    @compileProcess = new BufferedProcess #({command, args, stdout.bind @, stderr.bind @, exit.bind @})
        command: command
        args: args
        stdout: stdout.bind @
        stderr: stderr.bind @
        exit: exit.bind @

  OTAU: ->
    #if (doUpload == 2)
    @rootPath = atom.config.get("#{@packageName}.particleRootPath")
    @device_ID = @profileManager.getLocal('current-device')
    @platform = @profileManager.currentTargetPlatform
    @app = atom.workspace.getActivePaneItem().buffer.file.getParent().getBaseName()
    @firmware_BIN_Path = @rootPath + 'build/target/user-part/platform-' + @platform + '-m/' + @app + '.bin'

    if !@profileManager.hasCurrentDevice
      console.log("[OTA] No Device Selected")
      @consolePanel.error("[OTA] No Device Selected")
      return

    if !@device_ID.connected
      @consolePanel.error("[OTA] Device is not connected to the cloud!")
      return

    #compileComplete = @compile(0)

    #if(compileComplete)
    command = 'particle'
    args = [
      'flash',
      @device_ID.id.toString(), #Device_ID
      @firmware_BIN_Path, #Firmware .bin path
    ]

    console.log(@device_ID)
    @consolePanel.log(@device_ID)

    # debug to console
    stdout = (output) ->
      console.log("[OTA] STDOUT:", output)
      @consolePanel.log("[OTA] STDOUT:"+output.toString())
    stderr = (err) ->
      console.log("[OTA] STDERR:", err)
      @consolePanel.warn("[OTA] STDERR:"+err.toString())
    exit = (code) ->
      console.log("[OTA] Exited with #{code}")
      if code == 0
        @consolePanel.notice("[OTA] Exited with #{code}")
      else
        @consolePanel.error("[OTA] Exited with #{code}")

    console.log("[OTA] Command:", command,args.join(' '))
    @consolePanel.log("[OTA] Command: "+command+" "+args.join(' '))

    @OTAU_Process = new BufferedProcess #({command, args, stdout.bind @, stderr.bind @, exit.bind @})
        command: command
        args: args
        stdout: stdout.bind @
        stderr: stderr.bind @
        exit: exit.bind @

  setCompilerBase: (base) ->
    @compilerPath = atom.config.get("#{@packageName}.particleRootPath")
    @compilerPath = @compilerPath+base
    atom.config.set("#{@packageName}.particleCompilerPath",@compilerPath)
    console.log("[setCompilerBase]", @compilerPath)
    @consolePanel.log("compilerPath="+@compilerPath)

  setClean: (clean) ->
    atom.config.set("#{@packageName}.enableClean",clean)
    console.log("[enableClean]", clean)
    @consolePanel.log("Use clean="+clean)

  console: ->
    console.log("[console] Toggle console output panel (wip)")
