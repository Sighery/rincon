+++
date = "{{ .Date }}"
draft = true
title = "{{ replace .File.ContentBaseName '_' ' ' | title }}"
summary = ""
series = []
+++

{{< figure
	src="feature.webp"
	alt=""
	caption=""
	loading="eager"
	fetchpriority="high"
>}}
