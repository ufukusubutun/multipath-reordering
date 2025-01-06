all: fabric_exp.ipynb

clean:
	rm fabric_exp.ipynb

SNIPPETS := fabric-snippets/fab-config.md fabric-snippets/reserve-resources.md fabric-snippets/extend.md fabric-snippets/configure-resources.md fabric-snippets/offload-off.md fabric-snippets/draw-topo-detailed-labels.md fabric-snippets/log-in.md

fabric_exp.ipynb: $(SNIPPETS) custom-snippets/exp-def.md custom-snippets/conf-queue.md
	pandoc --wrap=none \
		-i fabric-snippets/fab-config.md \
		custom-snippets/exp-def.md \
		fabric-snippets/reserve-resources.md fabric-snippets/extend.md \
		fabric-snippets/configure-resources.md \
		fabric-snippets/offload-off.md \
		fabric-snippets/draw-topo-detailed-labels.md \
		fabric-snippets/log-in.md \
		custom-snippets/conf-queue.md \
		-o fabric_exp.ipynb  
