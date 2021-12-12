[![CI](https://github.com/blaugold/explo/actions/workflows/ci.yaml/badge.svg)](https://github.com/blaugold/explo/actions/workflows/ci.yaml)

<p align="center">
    <img src="https://github.com/blaugold/explo/raw/main/docs/images/explo_logo.png" width="240px">
</p>

---

Monorepo for **Explo**, a tool which allows you to explore the render tree of a
Flutter app in 3D, through an exploded representation.

| Component      | Description                                                            | Location                                             | Published at                                                                                                                                          |
| -------------- | ---------------------------------------------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| explo          | Flutter package to receive captured render tree data and visualize it. | [packages/explo](./packages/explo)                   | [![pub.dev](https://badgen.net/pub/v/explo)](https://pub.dev/packages/explo)                                                                          |
| explo_capture  | Flutter package to capture render tree data in a Flutter app.          | [packages/explo_capture](./packages/explo_capture)   | [![pub.dev](https://badgen.net/pub/v/explo_capture)](https://pub.dev/packages/explo_capture)                                                          |
| explo_ide_view | Explo web view for IDE plugins.                                        | [packages/explo_ide_view](./packages/explo_ide_view) |                                                                                                                                                       |
| explo-code     | VS Code extension to add support for Explo                             | [explo-code](./explo-code)                           | [![VS Marketplace](https://badgen.net/vs-marketplace/v/blaugold.explo-code)](https://marketplace.visualstudio.com/items?itemName=blaugold.explo-code) |
