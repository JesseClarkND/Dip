//
// Dip
//
// Copyright (c) 2015 Olivier Halligon <olivier@halligon.net>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

protocol TypeForwardingDefinition: DefinitionType {
  var implementingTypes: [Any.Type] { get }
  func doesImplements(type: Any.Type) -> Bool
}

extension Definition {
  
  public func implements<F>(type: F.Type, tag: DependencyTagConvertible? = nil, resolvingProperties: (DependencyContainer, F) throws -> () = { _ in }) -> Definition {
    let container = self.container!
    let key = DefinitionKey(type: F.self, typeOfArguments: U.self)
    
    let forwardDefinition = DefinitionBuilder<F, U> {
      $0.scope = scope
      
      $0.factory = { [factory] in
        guard let resolved = try factory($0) as? F else {
          throw DipError.DefinitionNotFound(key: key.tagged(container.context.tag))
        }
        return resolved
      }
      
      $0.numberOfArguments = numberOfArguments
      $0.autoWiringFactory = autoWiringFactory.map({ autoWiringFactory in
        {
          guard let resolved = try autoWiringFactory($0, $1) as? F else {
            throw DipError.DefinitionNotFound(key: key.tagged(container.context.tag))
          }
          return resolved
        }
      })
      
      $0.forwardsDefinition = self
      }.build()
      .resolvingProperties(resolvingProperties)
    
    container.register(forwardDefinition, forTag: tag)
    return self
  }

  public func implements<A, B>(a: A.Type, _ b: B.Type) -> Definition {
    return implements(a).implements(b)
  }

  public func implements<A, B, C>(a: A.Type, _ b: B.Type, _ c: C.Type) -> Definition {
    return implements(a).implements(b).implements(c)
  }

  public func implements<A, B, C, D>(a: A.Type, _ b: B.Type, c: C.Type, d: D.Type) -> Definition {
    return implements(a).implements(b).implements(c).implements(d)
  }

}

extension DependencyContainer {
  
  /**
   Registers definition for passed type.
   
   If instance created by definition factory does not implement registered type
   container will throw `DipError.DefinitionNotFound` error when trying to resolve that type.
   
   - parameters:
      - definition: Definition to register
      - type: Type to register definition for
      - tag: Optional tag to associate definition with. Default is `nil`.
   
   - returns: New definition for passed type.
   */
  @available(*, deprecated=5.0.0, message="Use implements(_:tag:resolvingProperties:) method of Definition instead.")
  public func register<T, U, F>(definition: Definition<T, U>, type: F.Type, tag: DependencyTagConvertible? = nil) -> Definition<F, U> {
    let key = DefinitionKey(type: F.self, typeOfArguments: U.self)
    
    let forwardDefinition = DefinitionBuilder<F, U> {
      $0.scope = definition.scope
      
      let factory = definition.factory
      $0.factory = { [unowned self] in
        guard let resolved = try factory($0) as? F else {
          throw DipError.DefinitionNotFound(key: key.tagged(self.context.tag))
        }
        return resolved
      }

      $0.numberOfArguments = definition.numberOfArguments
      $0.autoWiringFactory = definition.autoWiringFactory.map({ autoWiringFactory in
        { [unowned self] in
          guard let resolved = try autoWiringFactory($0, $1) as? F else {
            throw DipError.DefinitionNotFound(key: key.tagged(self.context.tag))
          }
          return resolved
        }
      })

      $0.forwardsDefinition = definition
      }.build()
    
    register(forwardDefinition, forTag: tag)
    return forwardDefinition
  }
  
  /// Searches for definition that forwards requested type
  func typeForwardingDefinition(key: DefinitionKey) -> KeyDefinitionPair? {
    var forwardingDefinitions = self.definitions.map({ (key: $0.0, definition: $0.1) })
    
    forwardingDefinitions = filter(forwardingDefinitions, byKeyAndTypeOfArguments: key)
    forwardingDefinitions = order(forwardingDefinitions, byTag: key.tag)

    //we need to carry on original tag
    return forwardingDefinitions.first.map({ ($0.key.tagged(key.tag), $0.definition) })
  }
  
}