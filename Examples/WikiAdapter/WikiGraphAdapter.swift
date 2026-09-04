import ForceGraphCore
import ForceGraphScene

struct WikiNote: Sendable {
  let id: String
  let title: String
  let wikilinks: [String]
}

func makeWikiScene(_ notes: [WikiNote]) -> ForceGraphScene<String, String> {
  let known = Set(notes.map(\.id))
  let nodes = notes.map {
    SceneNode(physics: ForceNode(id: $0.id), visual: NodeVisual(label: $0.title))
  }
  let links = notes.flatMap { note in
    note.wikilinks.filter(known.contains).sorted().map { target in
      SceneLink(
        id: "\(note.id)->\(target)",
        physics: ForceLink(source: note.id, target: target),
        visual: LinkVisual(isDirectional: true))
    }
  }
  return ForceGraphScene(nodes: nodes, links: links)
}
