(function () {
	var DPR_CAP = 2;

	function capped(value) {
		var ratio = Number(value);
		if (!isFinite(ratio) || ratio <= 0) {
			return 1;
		}
		return Math.min(DPR_CAP, ratio);
	}

	function capDevicePixelRatio(object) {
		if (!object) {
			return false;
		}
		var descriptor = Object.getOwnPropertyDescriptor(object, "devicePixelRatio");
		if (!descriptor || descriptor.configurable !== true) {
			return false;
		}
		if (typeof descriptor.get === "function") {
			var read = descriptor.get;
			Object.defineProperty(object, "devicePixelRatio", {
				configurable: true,
				enumerable: descriptor.enumerable,
				get: function () {
					return capped(read.call(this));
				},
			});
			return true;
		}
		Object.defineProperty(object, "devicePixelRatio", {
			configurable: true,
			enumerable: descriptor.enumerable,
			writable: true,
			value: capped(descriptor.value),
		});
		return true;
	}

	if (!capDevicePixelRatio(window)) {
		capDevicePixelRatio(Object.getPrototypeOf(window));
	}

	var viewport = document.querySelector('meta[name="viewport"]');
	if (!viewport) {
		viewport = document.createElement("meta");
		viewport.setAttribute("name", "viewport");
		document.head.appendChild(viewport);
	}
	viewport.setAttribute(
		"content",
		"width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover"
	);

	window.pocketHeistsSafeInsets = function () {
		var style = getComputedStyle(document.documentElement);
		function edge(name) {
			var value = parseFloat(style.getPropertyValue(name));
			if (!isFinite(value) || value < 0) {
				return 0;
			}
			return Math.round(value);
		}
		return [edge("--safe-left"), edge("--safe-top"), edge("--safe-right"), edge("--safe-bottom")].join(",");
	};

	function arm(canvas) {
		if (!canvas || canvas.dataset.pocketHost === "1") {
			return;
		}
		canvas.dataset.pocketHost = "1";
		canvas.style.touchAction = "none";
		canvas.style.overscrollBehavior = "none";
		canvas.addEventListener(
			"touchmove",
			function (event) {
				event.preventDefault();
			},
			{ passive: false }
		);
	}

	function bind() {
		arm(document.getElementById("canvas"));
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", bind);
	} else {
		bind();
	}
})();
