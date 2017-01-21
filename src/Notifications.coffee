class Notifications
	constructor: (@elem) ->
		@

	ids: {}

	register: (id,o) ->
		if (@ids[id])
			throw new Error("UniqueError: "+id+" is already registered")
		@ids[id]=o

	get: (id,th) ->
		if (!@ids[id] && th)
			throw new Error("UndefinedError: "+id+" is not registered")
		return @ids[id]

	unregister: (id,o) ->
		if (!@ids[id])
			throw new Error("UndefinedError: "+id+" is not registered")
		delete @ids[id]

	# TODO: add unit tests
	test: ->
		setTimeout (=>
			@add("connection", "error", "Connection lost to <b>UiServer</b> on <b>localhost</b>!")
			@add("message-Anyone", "info", "New  from <b>Anyone</b>.")
		), 1000
		setTimeout (=>
			@add("connection", "done", "<b>UiServer</b> connection recovered.", 5000)
		), 3000


	add: (id, type, body, timeout=0, options={}, cb) ->
		return new Notification @, {id,type,body,timeout,options,cb}

	close: (id) ->
		@get(id,true).close()

#	displayConfirm: (message, caption, cancel=false, cb) ->
#	displayPrompt: (message, type, caption, cb) ->

class Notification
	constructor: (@main,message) -> #(@id, @type, @body, @timeout=0) ->
		@main_elem=@main.elem
		@options=message.options
		@cb=message.cb
		@id = message.id.replace /[^A-Za-z0-9]/g, ""

		# Close notifications with same id
		if @main.get(@id)
			@main.get(@id).close()


		@type=message.type
		@["is"+@type.substr(0,1).toUpperCase()+@type.substr(1)]=true

		if @isProgress
			@RealTimeout=message.timeout #prevent from launching too early
		else if @isInput or @isConfirm #ignore
		else
			@Timeout=message.timeout

		@main.register(@id,@) #register

		@

		# Create element
		@elem = $(".notification.notificationTemplate", @main_elem).clone().removeClass("notificationTemplate") # TODO: get elem from notifications
		@elem.addClass("notification-#{@type}").addClass("notification-#{@id}")
		if @isProgress
			@elem.addClass("notification-done")
		# Update text
		@updateText @type

		body=message.body
		@body=body

		@rebuildMsg ""

		@elem.appendTo(@main_elem)

		# Timeout
		if @Timeout
			$(".close", @elem).remove() # No need of close button
			setTimeout (=>
				@close()
			), @Timeout

		#Init main stuff
		if @isProgress
			@setProgress(@options.progress||0)
		if @isPrompt
			@buildPrompt($(".body", @elem), @options.confirm_label||"Ok", @options.cancel_label||false)
		if @isConfirm
			@buildConfirm($(".body", @elem), @options.confirm_label||"Ok", @options.cancel_label||false)

		# Animate
		width = @elem.outerWidth()
		if not @Timeout then width += 20 # Add space for close button
		if @elem.outerHeight() > 55 then @elem.addClass("long")
		@elem.css({"width": "50px", "transform": "scale(0.01)"})
		@elem.animate({"scale": 1}, 800, "easeOutElastic")
		@elem.animate({"width": width}, 700, "easeInOutCubic")
		$(".body", @elem).cssLater("box-shadow", "0px 0px 5px rgba(0,0,0,0.1)", 1000)

		# Close button or Confirm button
		$(".close", @elem).on "click", =>
			@close("user",true)
			return false
		$(".button", @elem).on "click", =>
			@close()
			return false

		# Select list
		$(".select", @elem).on "click", =>
			@close()

	resizeBox: ->
		@elem.css("width","inherit")

	callBack: (event,res) ->
		if @called
			throw new Error("CalbackError: Callback was called twice")
		@called=true
		if typeof(@cb) != "function"
			console.warn("Silently failing callback @ %s: %s & '%s'",@id,event,res)
			return
		console.info("Event @ %s %s %s",@id,event,res)
		@cb(event,res)

	rebuildMsg: (append) ->
		@append=$(append)
		if typeof(@body) == "string"
			$(".body", @elem).html("<span class='message'>"+@escape(@body)+"</span>").append(@append)
		else
			$(".body", @elem).html("").append(@body,@append)

	escape: (value) ->
 		return String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/&lt;([\/]{0,1}(br|b|u|i))&gt;/g, "<$1>") # Escape and Unescape b, i, u, br tags

	setBody: (body) ->
		@body=body
		@rebuildMsg @append
		@resizeBox()
		return @

	buildConfirm: (body,caption,cancel=false) ->
		button = $("<a href='##{caption}' class='button button-#{caption}'>#{caption}</a>") # Add confirm button
		button.on "click", =>
			@callBack "action",true
			return false
		body.append(button)
		if (cancel)
			cButton = $("<a href='##{cancel}' class='button button-#{cancel}'>#{cancel}</a>") # Add confirm button
			cButton.on "click", =>
				@callBack "action",false
				return false
			body.append(cButton)

		button.focus()
		$(".notification").scrollLeft(0)


	buildPrompt: (body,caption,cancel=false) ->
		input = $("<input type='#{@type}' class='input button-#{@type}'/>") # Add input
		input.on "keyup", (e) => # Send on enter
			if e.keyCode == 13
				button.trigger "click" # Response to confirm
		body.append(input)

		button = $("<a href='##{caption}' class='button button-#{caption}'>#{caption}</a>") # Add confirm button
		button.on "click", => # Response on button click
			@callBack "action",input.val()
			return false
		body.append(button)
		if (cancel)
			cButton = $("<a href='##{cancel}' class='button button-#{cancel}'>#{cancel}</a>") # Add confirm button
			cButton.on "click", =>
				@callBack "action",false
				return false
			body.append(cButton)

		input.focus()
		$(".notification").scrollLeft(0)

	setProgress: (percent_) ->
		if typeof(percent_) != "number"
			throw new Error("TypeError: Progress must be int")
		@resizeBox()
		percent = Math.min(100, percent_)/100
		offset = 75-(percent*75)
		circle = """
			<div class="circle"><svg class="circle-svg" width="30" height="30" viewport="0 0 30 30" version="1.1" xmlns="http://www.w3.org/2000/svg">
  				<circle r="12" cx="15" cy="15" fill="transparent" class="circle-bg"></circle>
  				<circle r="12" cx="15" cy="15" fill="transparent" class="circle-fg" style="stroke-dashoffset: #{offset}"></circle>
			</svg></div>
		"""
		width = $(".body .message", @elem).outerWidth()
		#$(".body .message", @elem).html(message.params[1])
		@rebuildMsg circle
		if $(".body .message", @elem).css("width") == ""
			$(".body .message", @elem).css("width", width)
		$(".body .circle-fg", @elem).css("stroke-dashoffset", offset)
		if percent > 0
			$(".body .circle-bg", @elem).css {"animation-play-state": "paused", "stroke-dasharray": "180px"}

		if $(".notification-icon", @elem).data("done")
			return false
		else if percent_ >= 100  # Done
			$(".circle-fg", @elem).css("transition", "all 0.3s ease-in-out")
			setTimeout (->
				$(".notification-icon", @elem).css {transform: "scale(1)", opacity: 1}
				$(".notification-icon .icon-success", @elem).css {transform: "rotate(45deg) scale(1)"}
			), 300
			if @RealTimeout
				$(".close", @elem).remove() # It's already closing
				setTimeout (=>
					@close("auto",true)
				), @RealTimeout
			$(".notification-icon", @elem).data("done", true)
		else if percent_ < 0  # Error
			$(".body .circle-fg", @elem).css("stroke", "#ec6f47").css("transition", "transition: all 0.3s ease-in-out")
			setTimeout (=>
				$(".notification-icon", @elem).css {transform: "scale(1)", opacity: 1}
				@elem.removeClass("notification-done").addClass("notification-error")
				$(".notification-icon .icon-success", @elem).removeClass("icon-success").html("!")
			), 300
			$(".notification-icon", @elem).data("done", true)
		return @

	updateText: (type) ->
		if type == "error"
			$(".notification-icon", @elem).html("!")
		else if type == "done"
			$(".notification-icon", @elem).html("<div class='icon-success'></div>")
		else if type == "progress"
			$(".notification-icon", @elem).html("<div class='icon-success'></div>")
		else if type == "ask" || type == "list" || type == "prompt" || type == "confirm"
			$(".notification-icon", @elem).html("?")
		else if type == "info"
			$(".notification-icon", @elem).html("i")
		else
			throw new Error("UnknownNotificationType: Type "+type+" is not known")

	close: (event="auto",cb=false) ->
		if (cb||!@called)
			@callBack event
		$(".close", @elem).remove() # It's already closing
		@main.unregister(@id)
		@elem.stop().animate {"width": 0, "opacity": 0}, 700, "easeInOutCubic"
		elem=@elem
		@elem.slideUp 300, (-> elem.remove())
		return @main

window.Notifications = Notifications
