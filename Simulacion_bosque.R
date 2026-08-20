# -----------------------------------
# MBA de incendios con estadísticas finales (versión ajustada)
# -----------------------------------

# Paquetes
require_pkgs <- function(pkgs) {
  for (p in pkgs) if (!require(p, character.only = TRUE)) install.packages(p)
}
require_pkgs(c("ggplot2", "reshape2", "dplyr"))
library(ggplot2); library(reshape2); library(dplyr)

# ----------------------------
# Definir clase S4 Agent
# ----------------------------
setClass("Agent",
         slots = c(
           id         = "integer",
           x          = "integer",
           y          = "integer",
           energy     = "numeric",
           alert      = "numeric"
         )
)

# ----------------------------
# Parámetros globales
# ----------------------------
set.seed(55)
n           <- 50      # Tamaño del grid
n_agents    <- 200      # Número de guardabosques
r_com       <- 5       # Radio detección/comunicación
clean_rad   <- 10      # Radio limpieza
clean_cost  <- 0.05    # Costo energético limpieza
ext_cost    <- c(0.1, 0.2, 0.3) # Costos apagar niveles de fuego
fatal_cost  <- 0.2     # Energía perdida rodeo fuego
surround_threshold <- 5 # Celdas fuego para rodeo
max_steps   <- 10     # Límite iteraciones
dry_prob    <- 0.6     # Prob celda seca
clima       <- list(temp=38, viento=50, humedad=10)

# ----------------------------
# Funciones de inicialización
# ----------------------------
init_forest <- function(n, dry_prob) {
  mat <- matrix("tree", nrow=n, ncol=n)
  mat[sample(length(mat), dry_prob * length(mat))] <- "dry"
  mat[sample(which(mat == "dry"), 1)] <- "fire1"
  mat
}

init_agents <- function(n_agents, n) {
  lapply(seq_len(n_agents), function(i) {
    new("Agent",
        id = as.integer(i),
        x = as.integer(sample(2:(n-1), 1)),
        y = as.integer(sample(2:(n-1), 1)),
        energy = 1.0,
        alert = Inf)
  })
}

# ----------------------------
# Funciones auxiliares
# ----------------------------
interact_agents <- function(agents) {
  pos <- sapply(agents, function(a) paste(a@x, a@y, sep="_"))
  for (p in unique(pos[duplicated(pos)])) {
    ids <- which(pos == p)
    avgA <- mean(sapply(agents[ids], slot, "alert"))
    for (i in ids) agents[[i]]@alert <- avgA
  }
  agents
}

move_towards <- function(a, target, n) {
  a@x <- as.integer(pmin(pmax(a@x + sign(target[1] - a@x), 1), n))
  a@y <- as.integer(pmin(pmax(a@y + sign(target[2] - a@y), 1), n))
  a
}

random_move <- function(a, n) {
  a@x <- as.integer(pmin(pmax(a@x + sample(-1:1, 1), 1), n))
  a@y <- as.integer(pmin(pmax(a@y + sample(-1:1, 1), 1), n))
  a
}

# ----------------------------
# Propagación del fuego (niveles 1&2 sólo secas; nivel 3 seco+árbol)
# ----------------------------
spread_fire <- function(forest, clima) {
  f2 <- forest
  for (i in 2:(n-1)) for (j in 2:(n-1)) {
    cell <- forest[i,j]
    if (grepl("^fire", cell)) {
      lvl <- as.integer(substr(cell,5,5))
      # probabilidades base y extra para nivel3 en seco
      base_prob <- 0.6 + clima$viento * 0.1 - clima$humedad * 0.005
      dry_prob <- base_prob + ifelse(lvl==3, 0.2, 0)
      tree_prob <- ifelse(lvl==3, base_prob, 0)
      for (dx in -1:1) for (dy in -1:1) {
        neigh <- forest[i+dx, j+dy]
        if (lvl < 3) {
          if (neigh == "dry" && runif(1) < dry_prob) f2[i+dx, j+dy] <- "fire1"
        } else {
          if (neigh == "dry" && runif(1) < dry_prob) f2[i+dx, j+dy] <- "fire1"
          if (neigh == "tree" && runif(1) < tree_prob) f2[i+dx, j+dy] <- "fire1"
        }
      }
      # intensificación o quemado final
      f2[i,j] <- switch(cell,
                        fire1 = "fire2",
                        fire2 = "fire3",
                        fire3 = "burned")
    }
  }
  f2
}

# ----------------------------
# Visualización
# ----------------------------
plot_forest <- function(forest, agents, step) {
  df <- melt(forest)
  names(df) <- c("x","y","estado")
  df$agent <- FALSE
  for (a in agents) df$agent[df$x==a@x & df$y==a@y] <- TRUE
  ggplot(df, aes(x,y)) +
    geom_tile(aes(fill=estado), color="grey80") +
    scale_fill_manual(values = c(
      tree="forestgreen", dry="khaki",
      fire1="salmon", fire2="orangered", fire3="darkred",
      burned="black", extinguished="skyblue", cleared="lightgrey"
    )) +
    geom_point(data=subset(df,agent), aes(x,y), color="blue", size=3) +
    ggtitle(paste("Paso",step)) + theme_void() + theme(legend.position="bottom")
}

# ----------------------------
# Decisión de agentes
# ----------------------------
decide_action <- function(agent, forest, r_com, base) {
  idx <- which(grepl("^fire", forest))
  if (length(idx)>0) {
    pos <- arrayInd(idx, dim(forest))
    d2 <- (pos[,1]-agent@x)^2 + (pos[,2]-agent@y)^2
    agent@alert <- sqrt(min(d2))
    if (min(d2) <= r_com^2) return(list(type="go_fire", target=as.integer(pos[which.min(d2),])))
  }
  if (agent@energy < 0.2) return(list(type="rest", target=as.integer(base)))
  list(type="patrol", target=NULL)
}

# ----------------------------
# Estadísticas
# ----------------------------
stats <- data.frame(step=integer(), fire_cells=integer(), cleared_cells=integer(),
                    extinguished=integer(), agents_alive=integer(), agents_dead=integer())

# ----------------------------
# Simulación principal
# ----------------------------
forest <- init_forest(n, dry_prob)
agents <- init_agents(n_agents, n)
base <- c(as.integer(floor(n/2)), as.integer(floor(n/2)))
step <- 0

repeat {
  step <- step + 1
  forest <- spread_fire(forest, clima)
  updated <- list()
  for (a in agents) {
    # rodeo y fatal_cost
    neigh <- forest[pmax(1,a@x-1):pmin(n,a@x+1), pmax(1,a@y-1):pmin(n,a@y+1)]
    if (sum(grepl("^fire", neigh)) >= surround_threshold) {
      a@energy <- a@energy - fatal_cost
      if (a@energy <= 0) next
    }
    # acción
    act <- decide_action(a, forest, r_com, base)
    if (act$type=="go_fire") a <- move_towards(a, act$target, n)
    else if (act$type=="rest") {
      a <- move_towards(a, act$target, n)
      if (all(c(a@x,a@y)==base)) a@energy <- 1.0
    } else {
      a <- random_move(a, n)
      xi <- a@x; yi <- a@y
      if (forest[xi,yi]=="dry") {
        idx <- which(grepl("^fire", forest))
        if (length(idx)>0) {
          pos <- arrayInd(idx, dim(forest))
          if (min((pos[,1]-xi)^2 + (pos[,2]-yi)^2) <= clean_rad^2) {
            forest[xi,yi] <- "cleared"
            a@energy <- max(a@energy - clean_cost, 0)
          }
        }
      }
    }
    # apagar fuego con ext_cost y nivel
    xi <- a@x; yi <- a@y
    if (grepl("^fire", forest[xi,yi])) {
      lvl <- as.integer(substr(forest[xi,yi],5,5))
      forest[xi,yi] <- if(lvl<3) paste0("fire", lvl+1) else "extinguished"
      a@energy <- a@energy - ext_cost[lvl]
    }
    a@energy <- max(a@energy - 0.01, 0)
    updated <- c(updated, list(a))
  }
  agents <- interact_agents(updated)
  stats <- rbind(stats, data.frame(
    step=step,
    fire_cells=sum(grepl("^fire", forest)),
    cleared_cells=sum(forest=="cleared"),
    extinguished=sum(forest=="extinguished"),
    agents_alive=length(agents),
    agents_dead=n_agents-length(agents)
  ))
  print(plot_forest(forest, agents, step))
  Sys.sleep(0.2)
  if (!any(grepl("^fire", forest)) || 
      step >= max_steps || 
      !any(forest %in% c("tree", "dry"))) break
}

# ----------------------------
# Gráficos finales
# ----------------------------
ggplot(stats, aes(x=step)) +
  geom_line(aes(y=fire_cells), linetype="solid", color="red") +
  geom_line(aes(y=cleared_cells), linetype="dashed", color="gray") +
  geom_line(aes(y=extinguished), linetype="dotted", color="skyblue") +
  labs(y="Celdas", title="Evolución: fuego, limpieza, extinción")

ggplot(stats, aes(x=step)) +
  geom_line(aes(y=agents_alive), color="green") +
  geom_line(aes(y=agents_dead), color="red") +
  labs(y="Número de agentes", title="Supervivencia de agentes")
